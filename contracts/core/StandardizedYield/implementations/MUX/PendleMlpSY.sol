// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../SYBaseWithRewards.sol";
import "../../../../interfaces/MUX/IMUXRewardRouter.sol";
import "../../../../interfaces/IPPriceFeed.sol";

contract PendleMlpSY is SYBaseWithRewards {
    using Math for uint256;

    uint256 constant VEMUX_MAXTIME = 4 * 365 * 86400; // 4 years

    address public immutable mlp;
    address public immutable sMlp;
    address public immutable mux;
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
        mux = IMUXRewardRouter(_rewardRouter).mux();

        mlpPriceFeed = _mlpPriceFeed;

        // Dont have to approve for mlpMuxTracker as the contract allows whitelisted handlers
        // to transfer from anyone (MUX's reward router in this case)
        _safeApproveInf(mlp, IMUXRewardRouter(_rewardRouter).mlpFeeTracker());
        _safeApproveInf(mux, IMUXRewardRouter(_rewardRouter).votingEscrow());
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
        // IMUXRewardRouter(rewardRouter).compound() would revert in the case mux to be compounded = 0 (2 txns in the same block)
        // So we should not use that method
        IMUXRewardRouter(rewardRouter).claimAll();

        uint256 muxBalance = _selfBalance(mux);
        if (muxBalance > 0) {
            IMUXRewardRouter(rewardRouter).stakeMux(muxBalance, block.timestamp + VEMUX_MAXTIME);
        }
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
        res = new address[](2);
        res[0] = mlp;
        res[1] = sMlp;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = mlp;
        res[1] = sMlp;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == mlp || token == sMlp;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == mlp || token == sMlp;
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
