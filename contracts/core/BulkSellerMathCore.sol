// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./libraries/TokenHelper.sol";
import "./libraries/math/Math.sol";
import "./libraries/Errors.sol";

struct BulkSellerState {
    uint256 coreRateTokenToSy;
    uint256 coreRateSyToToken;
    uint256 feeRate;
    uint256 maxDiffRate;
    uint256 totalToken;
    uint256 totalSy;
    address token;
    address SY;
}

library BulkSellerMathCore {
    using Math for uint256;

    function swapExactTokenForSy(BulkSellerState memory state, uint256 netTokenIn)
        internal
        pure
        returns (uint256 netSyOut)
    {
        netSyOut = calcSwapExactTokenForSy(state, netTokenIn);

        if (netSyOut > state.totalSy)
            revert Errors.BulkInsufficientSyForTrade(state.totalSy, netSyOut);

        state.totalToken += netTokenIn;
        state.totalSy -= netSyOut;
    }

    function swapExactSyForToken(BulkSellerState memory state, uint256 netSyIn)
        internal
        pure
        returns (uint256 netTokenOut)
    {
        netTokenOut = calcSwapExactSyForToken(state, netSyIn);

        if (netTokenOut > state.totalToken)
            revert Errors.BulkInsufficientTokenForTrade(state.totalToken, netTokenOut);

        state.totalSy += netSyIn;
        state.totalToken -= netTokenOut;
    }

    function calcSwapExactTokenForSy(BulkSellerState memory state, uint256 netTokenIn)
        internal
        pure
        returns (uint256 netSyOut)
    {
        // TODO: maybe eliminate the fee rate in the calculation
        uint256 postFeeRate = state.coreRateTokenToSy.mulDown(Math.ONE - state.feeRate);
        require(postFeeRate != 0, "zero rate");
        netSyOut = netTokenIn.mulDown(postFeeRate);
    }

    function calcSwapExactSyForToken(BulkSellerState memory state, uint256 netSyIn)
        internal
        pure
        returns (uint256 netTokenOut)
    {
        uint256 postFeeRate = state.coreRateSyToToken.mulDown(Math.ONE - state.feeRate);
        require(postFeeRate != 0, "zero rate");
        netTokenOut = netSyIn.mulDown(postFeeRate);
    }

    function getTokenProportion(BulkSellerState memory state) internal pure returns (uint256) {
        uint256 totalToken = state.totalToken;
        uint256 totalTokenFromSy = state.totalSy.mulDown(state.coreRateSyToToken);
        return totalToken.divDown(totalToken + totalTokenFromSy);
    }

    function getReBalanceParams(BulkSellerState memory state, uint256 targetProportion)
        internal
        pure
        returns (uint256 netTokenToDeposit, uint256 netSyToRedeem)
    {
        uint256 currentProportion = getTokenProportion(state);

        if (currentProportion > targetProportion) {
            netTokenToDeposit = state.totalToken.mulDown(currentProportion - targetProportion);
        } else {
            netSyToRedeem = state.totalSy.mulDown(targetProportion - currentProportion);
        }
    }

    function reBalanceTokenToSy(
        BulkSellerState memory state,
        uint256 netTokenToDeposit,
        uint256 netSyFromToken
    ) internal pure {
        uint256 rate = netSyFromToken.divDown(netTokenToDeposit);

        require(Math.isAApproxB(rate, state.coreRateTokenToSy, state.maxDiffRate), "bad rate");

        state.totalToken -= netTokenToDeposit;
        state.totalSy += netSyFromToken;
    }

    function reBalanceSyToToken(
        BulkSellerState memory state,
        uint256 netSyToRedeem,
        uint256 netTokenFromSy
    ) internal pure {
        uint256 rate = netTokenFromSy.divDown(netSyToRedeem);

        require(Math.isAApproxB(rate, state.coreRateSyToToken, state.maxDiffRate), "bad rate");

        state.totalToken += netTokenFromSy;
        state.totalSy -= netSyToRedeem;
    }

    function updateRateTokenToSy(
        BulkSellerState memory state,
        function(address, uint256) external view returns (uint256) previewDeposit
    ) internal view {
        uint256 hypoTotalToken = state.totalToken + calcSwapExactSyForToken(state, state.totalSy);
        uint256 netSyFromToken = previewDeposit(state.token, hypoTotalToken);

        uint256 newRate = netSyFromToken.divDown(hypoTotalToken);
        require(Math.isAApproxB(newRate, state.coreRateTokenToSy, state.maxDiffRate), "bad rate");

        state.coreRateTokenToSy = newRate.Uint128();
    }

    function updateRateSyToToken(
        BulkSellerState memory state,
        function(address, uint256) external view returns (uint256) previewRedeem
    ) internal view {
        uint256 hypoTotalSy = state.totalSy + calcSwapExactTokenForSy(state, state.totalToken);
        uint256 netTokenFromSy = previewRedeem(state.token, hypoTotalSy);

        uint256 newRate = netTokenFromSy.divDown(hypoTotalSy);
        require(Math.isAApproxB(newRate, state.coreRateSyToToken, state.maxDiffRate), "bad rate");

        state.coreRateSyToToken = newRate.Uint128();
    }
}
