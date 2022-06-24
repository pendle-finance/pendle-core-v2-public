// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "../../base-implementations/SCYBaseWithRewards.sol";
import "../../../interfaces/IAToken.sol";
import "../../../interfaces/IAavePool.sol";
import "../../../interfaces/IAaveRewardsController.sol";
import "./WadRayMath.sol";

contract PendleAaveV3SCY is SCYBaseWithRewards {
    using Math for uint256;
    using WadRayMath for uint256;

    address public immutable underlying;
    address public immutable pool;
    address public immutable rewardsController;
    address public immutable aToken;

    uint256 private constant PRECISION_INDEX = 1e9;

    constructor(
        string memory _name,
        string memory _symbol,
        address _aToken
    ) SCYBaseWithRewards(_name, _symbol, _aToken) {
        aToken = _aToken;
        underlying = IAToken(aToken).UNDERLYING_ASSET_ADDRESS();
        rewardsController = IAToken(aToken).getIncentivesController();
        pool = IAToken(aToken).POOL();
        _safeApprove(underlying, pool, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address tokenIn, uint256 amountDeposited)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        // aTokenScaled -> SCY is 1:1
        if (tokenIn == aToken) {
            amountSharesOut = _aTokenToScaledBalance(amountDeposited);
        } else {
            uint256 preScaledBalance = IAToken(aToken).scaledBalanceOf(address(this));
            IAavePool(pool).supply(underlying, amountDeposited, address(this), 0);
            amountSharesOut = IAToken(aToken).scaledBalanceOf(address(this)) - preScaledBalance;
        }
    }

    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == aToken) {
            amountTokenOut = _scaledBalanceToAToken(amountSharesToRedeem);
        } else {
            uint256 preBalanceUnderlying = _selfBalance(underlying);

            uint256 amountATokenToWithdraw = _scaledBalanceToAToken(amountSharesToRedeem);
            IAavePool(pool).withdraw(underlying, amountATokenToWithdraw, address(this));

            // underlying is potentially also rewardToken, hence we need to manually track the balance here
            amountTokenOut = _selfBalance(underlying) - preBalanceUnderlying;
        }
    }

    function _updateYieldReserve() internal virtual override {
        yieldTokenReserve = IAToken(aToken).scaledBalanceOf(address(this));
    }

    function _getFloatingAmount(address token) internal view virtual override returns (uint256) {
        if (token != aToken) return _selfBalance(token) - rewardState[token].lastBalance;
        // the only reserve token is aToken
        uint256 scaledATokenAmount = IAToken(aToken).scaledBalanceOf(address(this)) -
            yieldTokenReserve;
        return _scaledBalanceToAToken(scaledATokenAmount);
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return _getReserveNormalizedIncome() / PRECISION_INDEX;
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    function _getRewardTokens() internal view override returns (address[] memory res) {
        res = IAaveRewardsController(rewardsController).getRewardsByAsset(aToken);
    }

    function _redeemExternalReward() internal override {
        address[] memory assets = new address[](1);
        assets[0] = aToken;

        IAaveRewardsController(rewardsController).claimAllRewards(assets, address(this));
    }

    /*///////////////////////////////////////////////////////////////
                               INTERNAL-HELPER-FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getReserveNormalizedIncome() internal view returns (uint256) {
        return IAavePool(pool).getReserveNormalizedIncome(underlying);
    }

    function _aTokenToScaledBalance(uint256 aTokenAmount) internal view returns (uint256) {
        return aTokenAmount.rayDiv(_getReserveNormalizedIncome());
    }

    function _scaledBalanceToAToken(uint256 scaledAmount) internal view returns (uint256) {
        return scaledAmount.rayMul(_getReserveNormalizedIncome());
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

    function assetInfo()
        external
        view
        returns (
            AssetType assetType,
            address assetAddress,
            uint8 assetDecimals
        )
    {
        return (AssetType.TOKEN, underlying, IERC20Metadata(underlying).decimals());
    }
}
