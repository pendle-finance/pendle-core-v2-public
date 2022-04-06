// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;
import "../../SuperComposableYield/implementations/SCYBaseWithRewards.sol";
import "../../interfaces/IAToken.sol";
import "../../interfaces/IAavePool.sol";
import "../../interfaces/IAaveRewardsController.sol";
import "../../libraries/math/WadRayMath.sol";

contract PendleAaveV3SCY is SCYBaseWithRewards {
    using WadRayMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable underlying;
    address public immutable pool;
    address public immutable rewardsController;
    address public immutable aToken;

    uint256 public lastSCYIndex;

    // WIP: Aave reward controller can config to have more rewardsToken,
    // hence rewardsLength should not be immutable
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __scydecimals,
        uint8 __assetDecimals,
        address _aavePool,
        address _underlying,
        address _aToken,
        address _rewardsController
    ) SCYBaseWithRewards(_name, _symbol, __scydecimals, __assetDecimals) {
        aToken = _aToken;
        pool = _aavePool;
        underlying = _underlying;
        rewardsController = _rewardsController;
        IERC20(underlying).safeIncreaseAllowance(aToken, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address token, uint256 amountBase)
        internal
        virtual
        override
        returns (uint256 amountSCYOut)
    {
        // aTokenScaled -> scy is 1:1
        if (token == aToken) {
            amountSCYOut = amountBase.rayDiv(scyIndexCurrent());
        } else {
            IAavePool(pool).supply(underlying, amountBase, address(this), 0);
            _afterSendToken(underlying);
            amountSCYOut = _afterReceiveToken(aToken);
        }
    }

    function _redeem(address token, uint256 amountSCY)
        internal
        virtual
        override
        returns (uint256 amountBaseOut)
    {
        if (token == aToken) {
            amountBaseOut = amountSCY.rayMul(scyIndexCurrent());
        } else {
            uint256 amountBaseExpected = amountSCY.rayMul(scyIndexCurrent());
            IAavePool(pool).withdraw(underlying, amountBaseExpected, address(this));
            _afterSendToken(aToken);
            amountBaseOut = _afterReceiveToken(token);
        }
    }

    /*///////////////////////////////////////////////////////////////
                               SCY-INDEX
    //////////////////////////////////////////////////////////////*/

    function scyIndexCurrent() public virtual override returns (uint256 res) {
        res = IAavePool(pool).getReserveNormalizedIncome(underlying);
        lastSCYIndex = res;
        return res;
    }

    function scyIndexStored() public view override returns (uint256 res) {
        res = lastSCYIndex;
    }

    function getRewardTokens() public view override returns (address[] memory res) {
        return IAaveRewardsController(rewardsController).getRewardsByAsset(aToken);
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function getBaseTokens() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = underlying;
        res[1] = aToken;
    }

    function isValidBaseToken(address token) public view virtual override returns (bool res) {
        res = (token == underlying || token == aToken);
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    function _redeemExternalReward() internal override {
        address[] memory assets = new address[](1);
        assets[0] = aToken;

        IAaveRewardsController(rewardsController).claimAllRewards(assets, address(this));
    }

    /// @dev balance of aToken is saved by scaledBalanceOf instead
    function _afterReceiveToken(address token) internal virtual override returns (uint256 res) {
        if (token == aToken) {
            uint256 curBalance = IAToken(aToken).scaledBalanceOf(address(this));
            res = (curBalance - lastBalanceOf[token]).rayMul(scyIndexCurrent());
            lastBalanceOf[token] = curBalance;
        } else {
            uint256 curBalance = IERC20(token).balanceOf(address(this));
            res = curBalance - lastBalanceOf[token];
            lastBalanceOf[token] = curBalance;
        }
    }

    function _afterSendToken(address token) internal virtual override {
        if (token == aToken) {
            lastBalanceOf[token] = IAToken(aToken).scaledBalanceOf(address(this));
        } else {
            lastBalanceOf[token] = IERC20(token).balanceOf(address(this));
        }
    }
}
