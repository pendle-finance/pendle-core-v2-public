// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;
import "./PendleLiquidYieldTokenBase.sol";
import "../../interfaces/IBenQiComptroller.sol";
import "../../interfaces/IJoeRouter01.sol";
import "../../interfaces/IQiErc20.sol";
import "../../interfaces/IQiToken.sol";
import "../../interfaces/IWETH.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/math/Math.sol";

contract PendleBenqiLiquidYieldToken is PendleLiquidYieldTokenBase {
    using SafeERC20 for IERC20;
    address public immutable comptroller;
    address public immutable weth;
    address public immutable joeRouter;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint8 _underlyingDecimals,
        address[] memory _rewardTokens,
        address _underlyingYieldToken,
        address _comptroller,
        address _weth,
        address _joeRouter
    )
        PendleLiquidYieldTokenBase(
            _name,
            _symbol,
            __decimals,
            _underlyingDecimals,
            _rewardTokens,
            _underlyingYieldToken
        )
    {
        comptroller = _comptroller;
        weth = _weth;
        joeRouter = _joeRouter;
    }

    function mint(address to, uint256 amount) public override {
        IERC20(underlyingYieldToken).safeTransferFrom(msg.sender, address(this), amount);
        _mint(to, amount);
    }

    function mintFromBaseToken(
        address to,
        address token,
        uint256 amount,
        uint256 minAmountLYTOut,
        bytes memory data
    ) public override returns (uint256 amountLYTOut) {
        (address[] memory path, uint256 expiry) = abi.decode(data, (address[], uint256));
        require(token == path[0], "INVALID_PATH");
        uint256 amountUnderlying = IJoeRouter01(joeRouter).swapExactTokensForTokens(
            amount,
            1,
            path,
            to,
            expiry
        )[path.length - 1];

        uint256 balanceBefore = IQiErc20(underlyingYieldToken).balanceOf(to);
        IQiErc20(underlyingYieldToken).mint(amountUnderlying);
        uint256 balanceAfter = IQiErc20(underlyingYieldToken).balanceOf(to);

        amountLYTOut = balanceAfter - balanceBefore;
        require(amountLYTOut >= minAmountLYTOut, "INSUFFICIENT_OUT_AMOUNT");
        _mint(to, amountLYTOut);
    }

    function burn(address to, uint256 amount) public override {
        _burn(msg.sender, amount);
        IERC20(underlyingYieldToken).safeTransfer(to, amount);
    }

    function burnToBaseToken(
        address to,
        address token,
        uint256 amount,
        uint256 minAmountTokenOut,
        bytes memory data
    ) public override returns (uint256 amountTokenOut) {
        _burn(to, amount);

        (address[] memory path, uint256 expiry) = abi.decode(data, (address[], uint256));
        require(token == path[path.length - 1], "INVALID_PATH");

        uint256 balanceBefore = IERC20(path[0]).balanceOf(to);
        IQiErc20(underlyingYieldToken).redeem(amount);
        uint256 balanceAfter = IERC20(path[0]).balanceOf(to);

        uint256 amountUnderlyingOut = balanceAfter - balanceBefore;
        amountTokenOut = IJoeRouter01(joeRouter).swapExactTokensForTokens(
            amountUnderlyingOut,
            1,
            path,
            to,
            expiry
        )[path.length - 1];
        require(amountTokenOut >= minAmountTokenOut, "INSUFFICIENT_OUT_AMOUNT");
    }

    function exchangeRateCurrent() public override returns (uint256) {
        exchangeRateStored = Math.max(
            exchangeRateStored,
            IQiToken(underlyingYieldToken).exchangeRateCurrent()
        );
        return exchangeRateStored;
    }

    function redeemReward() public override returns (uint256[] memory outAmounts) {
        updateUserReward(msg.sender);

        outAmounts = new uint256[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            outAmounts[i] = userReward[msg.sender][i].accuredReward;
            userReward[msg.sender][i].accuredReward = 0;

            globalReward[i].lastBalance -= outAmounts[i];

            if (outAmounts[i] != 0) {
                IERC20(rewardTokens[i]).safeTransfer(msg.sender, outAmounts[i]);
            }
        }
    }

    function claimRewardToLYT() public {
        address[] memory holders = new address[](1);
        address[] memory qiTokens = new address[](1);
        holders[0] = address(this);
        qiTokens[0] = underlyingYieldToken;
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            IBenQiComptroller(comptroller).claimReward(uint8(i), holders, qiTokens, false, true);
        }

        if (address(this).balance != 0) IWETH(weth).deposit{ value: address(this).balance };
    }

    function updateGlobalReward() public override {
        claimRewardToLYT();

        uint256 totalLYT = totalSupply();
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            uint256 currentRewardBalance;
            currentRewardBalance = IERC20(rewardTokens[i]).balanceOf(address(this));
            if (totalLYT != 0) {
                globalReward[i].index += FixedPoint.divUp(
                    (currentRewardBalance - globalReward[i].lastBalance),
                    totalLYT
                );
            }
            globalReward[i].lastBalance = currentRewardBalance;
        }
    }

    function _updateUserRewardSkipGlobal(address user) internal override {
        uint256 principle = balanceOf(user);
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            uint256 userLastIndex = userReward[user][i].lastIndex;
            if (userLastIndex == globalReward[i].index) continue;

            uint256 rewardAmountPerLYT = globalReward[i].index - userLastIndex;
            uint256 rewardFromLYT = FixedPoint.mulDown(principle, rewardAmountPerLYT);

            userReward[user][i].accuredReward += rewardFromLYT;
            userReward[user][i].lastIndex = globalReward[i].index;
        }
    }
}
