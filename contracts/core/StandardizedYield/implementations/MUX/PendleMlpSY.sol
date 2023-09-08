// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../SYBaseWithRewards.sol";
import "../../../../interfaces/MUX/IMUXRewardRouter.sol";
import "../../../../interfaces/IPPriceFeed.sol";

contract PendleMlpSY is SYBaseWithRewards {
    using Math for uint256;

    address public immutable mlp;
    address public immutable sMlp;
    address public immutable weth;
    address public immutable rewardRouter;

    // non-security related
    address public immutable mlpPriceFeed;

    constructor(
        address _rewardRouter,
        address _mlpPriceFeed
    ) SYBaseWithRewards("SY MUXLP", "SY-MUXLP", IMUXRewardRouter(_rewardRouter).mlp()) {
        rewardRouter = _rewardRouter;
        weth = IMUXRewardRouter(_rewardRouter).weth();
        mlp = IMUXRewardRouter(_rewardRouter).mlp();
        sMlp = IMUXRewardRouter(_rewardRouter).mlpMuxTracker();

        mlpPriceFeed = _mlpPriceFeed;

        // Dont have to approve for mlpMuxTracker as the contract allows whitelisted handlers
        // to transfer from anyone (MUX's reward router in this case)
        _safeApproveInf(mlp, IMUXRewardRouter(_rewardRouter).mlpFeeTracker());
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == mlp) {
            IMUXRewardRouter(rewardRouter).stakeMlp(amountDeposited);
        }
        return amountDeposited;
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 /*amountTokenOut*/) {
        if (tokenOut == mlp) {
            IMUXRewardRouter(rewardRouter).unstakeMlp(amountSharesToRedeem);
        }
        _transferOut(tokenOut, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return Math.ONE;
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {IStandardizedYield-getRewardTokens}
     */
    function _getRewardTokens() internal view override returns (address[] memory res) {
        res = new address[](1);
        res[0] = weth;
    }

    function _redeemExternalReward() internal override {
        IMUXRewardRouter(rewardRouter).compound(); // compound should only claim
        IMUXRewardRouter(rewardRouter).claimAll();
        // this contract now should have 0 balance on MUX (all compounded to veMUX in the first step)
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address,
        uint256 amountTokenToDeposit
    ) internal view override returns (uint256 /*amountSharesOut*/) {
        return amountTokenToDeposit;
    }

    function _previewRedeem(
        address,
        uint256 amountSharesToRedeem
    ) internal view override returns (uint256 /*amountTokenOut*/) {
        return amountSharesToRedeem;
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](1);
        res[0] = mlp;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](1);
        res[0] = mlp;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == mlp;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == mlp;
    }

    function assetInfo()
        external
        view
        returns (AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (AssetType.LIQUIDITY, mlp, IERC20Metadata(mlp).decimals());
    }

    /*///////////////////////////////////////////////////////////////
                        OFF-CHAIN USAGE ONLY
            (NO SECURITY RELATED && CAN BE LEFT UNAUDITED)
    //////////////////////////////////////////////////////////////*/

    function getPrice() external view returns (uint256) {
        return IPPriceFeed(mlpPriceFeed).getPrice();
    }
}
