// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;
import "./PendleLiquidYieldTokenBase.sol";
import "./PendleJoeSwapHelper.sol";
import "../../interfaces/IBenQiComptroller.sol";
import "../../interfaces/IJoeRouter01.sol";
import "../../interfaces/IQiErc20.sol";
import "../../interfaces/IQiToken.sol";
import "../../interfaces/IWETH.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/math/Math.sol";

contract PendleBenqiLiquidYieldToken is PendleLiquidYieldTokenBase, PendleJoeSwapHelper {
    using SafeERC20 for IERC20;
    address public immutable comptroller;
    address public immutable weth;
    address public immutable baseToken;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint8 _underlyingDecimals,
        address[] memory _rewardTokens,
        address _underlying,
        address _comptroller,
        address _weth,
        address _joeRouter,
        address _joeFactory
    )
        PendleLiquidYieldTokenBase(
            _name,
            _symbol,
            __decimals,
            _underlyingDecimals,
            _rewardTokens,
            _underlying
        )
        PendleJoeSwapHelper(_joeRouter, _joeFactory)
    {
        comptroller = _comptroller;
        weth = _weth;
        baseToken = IQiErc20(underlying).underlying();
    }

    function mint(address recipient, uint256 amountUnderlyingIn)
        public
        override
        returns (uint256 amountLytOut)
    {
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amountUnderlyingIn);

        amountLytOut = amountUnderlyingIn;

        _mint(recipient, amountLytOut);
    }

    function mintFromRawToken(
        address recipient,
        address rawToken,
        uint256 amountRawIn,
        uint256 minAmountLytOut,
        bytes calldata data
    ) public override returns (uint256 amountLytOut) {
        IERC20(rawToken).safeTransferFrom(msg.sender, address(this), amountRawIn);

        uint256 amountBaseToken;
        if (rawToken != baseToken) {
            // requires swapping
            address[] memory path = abi.decode(data, (address[]));
            amountBaseToken = _swapExactIn(path, amountRawIn);
        } else {
            amountBaseToken = amountRawIn;
        }

        uint256 amountUnderlying = _mintQiToken(amountBaseToken);

        amountLytOut = amountUnderlying;

        require(amountLytOut >= minAmountLytOut, "INSUFFICIENT_OUT_AMOUNT");

        _mint(recipient, amountLytOut);
    }

    function burn(address recipient, uint256 amountLytIn)
        public
        override
        returns (uint256 amountUnderlyingOut)
    {
        _burn(msg.sender, amountLytIn);

        amountUnderlyingOut = amountLytIn;

        IERC20(underlying).safeTransfer(recipient, amountUnderlyingOut);
    }

    function burnToRawToken(
        address recipient,
        address rawToken,
        uint256 amountLytIn,
        uint256 minAmountRawOut,
        bytes calldata data
    ) public override returns (uint256 amountRawOut) {
        _burn(msg.sender, amountLytIn);

        uint256 amountUnderlying = amountLytIn;

        uint256 amountBaseToken = _burnQiToken(amountUnderlying);

        if (rawToken != baseToken) {
            // requires swapping
            address[] memory path = abi.decode(data, (address[]));
            amountRawOut = _swapExactIn(path, amountBaseToken);
        } else {
            amountRawOut = amountBaseToken;
        }

        require(amountRawOut >= minAmountRawOut, "INSUFFICIENT_OUT_AMOUNT");

        IERC20(rawToken).safeTransfer(recipient, amountRawOut);
    }

    function exchangeRateCurrent() public override returns (uint256) {
        lastExchangeRate = Math.max(lastExchangeRate, IQiToken(underlying).exchangeRateCurrent());
        return lastExchangeRate;
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
        qiTokens[0] = underlying;
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

    function _mintQiToken(uint256 amountBase) internal returns (uint256 amountUnderlyingMinted) {
        uint256 preBalance = IERC20(underlying).balanceOf(address(this));
        IQiErc20(underlying).mint(amountBase);
        uint256 postBalance = IERC20(underlying).balanceOf(address(this));

        amountUnderlyingMinted = postBalance - preBalance;
    }

    function _burnQiToken(uint256 amountUnderlying) internal returns (uint256 amountBaseReceived) {
        uint256 preBalance = IERC20(baseToken).balanceOf(address(this));
        IQiErc20(underlying).redeem(amountUnderlying);
        uint256 postBalance = IERC20(baseToken).balanceOf(address(this));

        amountBaseReceived = postBalance - preBalance;
    }
}
