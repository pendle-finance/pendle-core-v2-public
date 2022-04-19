// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
pragma abicoder v2;
import "../../../SuperComposableYield/implementations/SCYBaseWithRewards.sol";
import "../../../interfaces/IAToken.sol";
import "../../../interfaces/IAavePool.sol";
import "../../../interfaces/IAaveRewardsController.sol";
import "./WadRayMath.sol";

contract PendleAaveV3SCY is SCYBaseWithRewards {
    using Math for uint256;
    using WadRayMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable underlying;
    address public immutable pool;
    address public immutable rewardsController;
    address public immutable aToken;

    uint256 public lastScyIndex;
    uint256 public PRECISION_INDEX = 1e9;

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
        IERC20(underlying).safeIncreaseAllowance(pool, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address token, uint256 amountBase)
        internal
        virtual
        override
        returns (uint256 amountScyOut)
    {
        // aTokenScaled -> scy is 1:1
        if (token == aToken) {
            amountScyOut = amountBase;
        } else {
            IAavePool(pool).supply(underlying, amountBase, address(this), 0);
            _afterSendToken(underlying);
            amountScyOut = _afterReceiveToken(aToken);
        }
    }

    function _redeem(address token, uint256 amountScy)
        internal
        virtual
        override
        returns (uint256 amountBaseOut)
    {
        if (token == aToken) {
            amountBaseOut = amountScy.rayMul(aaveIndexCurrent());
        } else {
            uint256 amountBaseExpected = amountScy.rayMul(aaveIndexCurrent());
            IAavePool(pool).withdraw(underlying, amountBaseExpected, address(this));
            _afterSendToken(aToken);
            amountBaseOut = _afterReceiveToken(token);
        }
    }

    /*///////////////////////////////////////////////////////////////
                               SCY-INDEX
    //////////////////////////////////////////////////////////////*/

    function scyIndexCurrent() public virtual override returns (uint256 res) {
        aaveIndexCurrent();
        res = lastScyIndex;
    }

    function aaveIndexCurrent() public returns (uint256 res) {
        res = IAavePool(pool).getReserveNormalizedIncome(underlying);
        lastScyIndex = res / PRECISION_INDEX;
    }

    function scyIndexStored() public view override returns (uint256 res) {
        res = lastScyIndex;
    }

    function getRewardTokens() public view override returns (address[] memory res) {
        res = IAaveRewardsController(rewardsController).getRewardsByAsset(aToken);
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
        uint256 curBalance = (token == aToken)? IAToken(aToken).scaledBalanceOf(address(this)) : IERC20(token).balanceOf(address(this));
        res = curBalance - lastBalanceOf[token];
        lastBalanceOf[token] = curBalance;
    }

    function _afterSendToken(address token) internal virtual override {
        if (token == aToken) {
            lastBalanceOf[token] = IAToken(aToken).scaledBalanceOf(address(this));
        } else {
            lastBalanceOf[token] = IERC20(token).balanceOf(address(this));
        }
    }
}
