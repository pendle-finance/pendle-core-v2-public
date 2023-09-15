// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../../SYBaseWithRewards.sol";
import "../../../../interfaces/Silo/ISiloIncentiveController.sol";
import "../../../../interfaces/Silo/ISilo.sol";
import "../../../../interfaces/Silo/ISiloLens.sol";
import "../../../libraries/ArrayLib.sol";
import "../../../libraries/math/PMath.sol";

contract PendleSiloWithIncentiveSY is SYBaseWithRewards {
    using PMath for uint256;

    address public immutable asset;
    address public immutable collateralToken;
    address public immutable silo;
    address public immutable incentiveController;
    address public immutable siloLens;
    address public immutable rewardToken;

    constructor(
        string memory _name,
        string memory _symbol,
        address _asset,
        address _collateralToken,
        address _silo,
        address _incentiveController,
        address _siloLens
    ) SYBaseWithRewards(_name, _symbol, _collateralToken) {
        asset = _asset;
        collateralToken = _collateralToken;
        silo = _silo;
        incentiveController = _incentiveController;
        siloLens = _siloLens;

        rewardToken = ISiloIncentiveController(incentiveController).REWARD_TOKEN();

        _safeApproveInf(asset, silo);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == collateralToken) {
            return amountDeposited;
        } else {
            (, amountSharesOut) = ISilo(silo).deposit(asset, amountDeposited, false);
        }
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        if (tokenOut == collateralToken) {
            _transferOut(collateralToken, receiver, amountSharesToRedeem);
            return amountSharesToRedeem;
        } else {
            // Silo withdrawing interface only accepts amount of asset as input
            // Therefore we need to ensure that assetInput.toShareRoundUp() <= amountSharesToRedeem

            // Preview functions go through base 1e18 before getting the result (using _exchangeRate()),
            // so it's easier to prove the accuracy of this method if we do it manually here
            uint256 totalDeposit = ISiloLens(siloLens).totalDepositsWithInterest(silo, asset);

            amountTokenOut =
                (totalDeposit * amountSharesToRedeem) /
                IERC20(collateralToken).totalSupply(); // round down should ensure that shares being burned <= amountSharesToRedeem

            // amountAssetToWithdraw should = withdrawnAmount as withdrawing does not
            // bear any fees
            ISilo(silo).withdraw(asset, amountTokenOut, false);
            _transferOut(tokenOut, receiver, amountTokenOut);
        }
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return _exchangeRate();
    }

    function _exchangeRate() internal view returns (uint256) {
        uint256 totalDeposit = ISiloLens(siloLens).totalDepositsWithInterest(silo, asset);
        uint256 totalShares = IERC20(collateralToken).totalSupply();
        return totalDeposit.divDown(totalShares);
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {IStandardizedYield-getRewardTokens}
     */
    function _getRewardTokens() internal view override returns (address[] memory) {
        return ArrayLib.create(rewardToken);
    }

    function _redeemExternalReward() internal override {
        ISiloIncentiveController(incentiveController).claimRewardsToSelf(
            ArrayLib.create(asset),
            type(uint256).max
        );
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view override returns (uint256 amountSharesOut) {
        if (tokenIn == collateralToken) {
            return amountTokenToDeposit;
        } else {
            return amountTokenToDeposit.divDown(_exchangeRate());
        }
    }

    function _previewRedeem(
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal view override returns (uint256 amountTokenOut) {
        if (tokenOut == collateralToken) {
            return amountSharesToRedeem;
        } else {
            return amountSharesToRedeem.mulDown(_exchangeRate());
        }
    }

    function getTokensIn() public view virtual override returns (address[] memory) {
        return ArrayLib.create(asset, collateralToken);
    }

    function getTokensOut() public view virtual override returns (address[] memory) {
        return ArrayLib.create(asset, collateralToken);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == asset || token == collateralToken;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == asset || token == collateralToken;
    }

    function assetInfo()
        external
        view
        returns (AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (AssetType.TOKEN, collateralToken, IERC20Metadata(collateralToken).decimals());
    }
}
