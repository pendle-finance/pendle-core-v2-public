// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "../../SYBaseWithRewards.sol";
import "./libraries/AaveAdapterLib.sol";
import "../../../../interfaces/AaveV3/IAaveV3AToken.sol";
import "../../../../interfaces/AaveV3/IAaveV3Pool.sol";
import "../../../../interfaces/AaveV3/IAaveV3IncentiveController.sol";

// @NOTE: In this contract, we denote the "scaled balance" term as "share"
contract PendleAaveV3WithRewardsSY is SYBaseWithRewards {
    using PMath for uint256;

    // solhint-disable immutable-vars-naming
    address public immutable aToken;
    address public immutable aavePool;
    address public immutable underlying;

    address public incentiveController;
    address[] public rewardTokens;

    constructor(
        string memory _name,
        string memory _symbol,
        address _aavePool,
        address _aToken
    ) SYBaseWithRewards(_name, _symbol, _aToken) {
        aToken = _aToken;
        aavePool = _aavePool;
        underlying = IAaveV3AToken(aToken).UNDERLYING_ASSET_ADDRESS();

        _updateIncentiveController();

        _safeApproveInf(underlying, _aavePool);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == underlying) {
            IAaveV3Pool(aavePool).supply(underlying, amountDeposited, address(this), 0);
        }
        amountSharesOut = AaveAdapterLib.calcSharesFromAssetUp(amountDeposited, _getNormalizedIncome());
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal override returns (uint256 amountTokenOut) {
        amountTokenOut = AaveAdapterLib.calcSharesToAssetDown(amountSharesToRedeem, _getNormalizedIncome());
        if (tokenOut == underlying) {
            IAaveV3Pool(aavePool).withdraw(underlying, amountTokenOut, receiver);
        } else {
            _transferOut(aToken, receiver, amountTokenOut);
        }
    }

    function exchangeRate() public view virtual override returns (uint256) {
        return _getNormalizedIncome() / 1e9;
    }

    function _previewDeposit(
        address,
        uint256 amountTokenToDeposit
    ) internal view override returns (uint256 /*amountSharesOut*/) {
        return AaveAdapterLib.calcSharesFromAssetUp(amountTokenToDeposit, _getNormalizedIncome());
    }

    function _previewRedeem(
        address,
        uint256 amountSharesToRedeem
    ) internal view override returns (uint256 /*amountTokenOut*/) {
        return AaveAdapterLib.calcSharesToAssetDown(amountSharesToRedeem, _getNormalizedIncome());
    }

    function _getNormalizedIncome() internal view returns (uint256) {
        return IAaveV3Pool(aavePool).getReserveNormalizedIncome(underlying);
    }

    function getTokensIn() public view override returns (address[] memory res) {
        return ArrayLib.create(underlying, aToken);
    }

    function getTokensOut() public view override returns (address[] memory res) {
        return ArrayLib.create(underlying, aToken);
    }

    function isValidTokenIn(address token) public view override returns (bool) {
        return token == aToken || token == underlying;
    }

    function isValidTokenOut(address token) public view override returns (bool) {
        return token == aToken || token == underlying;
    }

    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, underlying, IERC20Metadata(underlying).decimals());
    }

    /*///////////////////////////////////////////////////////////////
                            REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {IStandardizedYield-getRewardTokens}
     */
    function _getRewardTokens() internal view override returns (address[] memory res) {
        return rewardTokens;
    }

    function _redeemExternalReward() internal override {
        _updateIncentiveController();
        IAaveV3IncentiveController(incentiveController).claimAllRewardsToSelf(ArrayLib.create(aToken));
    }

    function _updateIncentiveController() internal {
        address currentIncentiveController = IAaveV3AToken(aToken).getIncentivesController();
        if (currentIncentiveController == incentiveController) return;
        if (incentiveController != address(0)) {
            // claim old incentive controller rewards
            IAaveV3IncentiveController(incentiveController).claimAllRewardsToSelf(ArrayLib.create(aToken));
        } 

        incentiveController = currentIncentiveController;
        rewardTokens = ArrayLib.merge(
            rewardTokens,
            IAaveV3IncentiveController(currentIncentiveController).getRewardsList()
        );
    }
}
