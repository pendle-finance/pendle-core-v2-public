// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./libraries/TokenHelper.sol";
import "./libraries/math/Math.sol";
import "./libraries/Errors.sol";

struct BulkSellerState {
    uint256 rateTokenToSy;
    uint256 rateSyToToken;
    uint256 totalToken;
    uint256 totalSy;
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
        assert(state.rateTokenToSy != 0);
        netSyOut = netTokenIn.mulDown(state.rateTokenToSy);
    }

    function calcSwapExactSyForToken(BulkSellerState memory state, uint256 netSyIn)
        internal
        pure
        returns (uint256 netTokenOut)
    {
        assert(state.rateSyToToken != 0);
        netTokenOut = netSyIn.mulDown(state.rateSyToToken);
    }

    function getTokenProp(BulkSellerState memory state) internal pure returns (uint256) {
        uint256 totalToken = state.totalToken;
        uint256 totalTokenFromSy = state.totalSy.mulDown(state.rateSyToToken);
        return totalToken.divDown(totalToken + totalTokenFromSy);
    }

    function getReBalanceParams(BulkSellerState memory state, uint256 targetTokenProp)
        internal
        pure
        returns (uint256 netTokenToDeposit, uint256 netSyToRedeem)
    {
        uint256 currentTokenProp = getTokenProp(state);

        if (currentTokenProp > targetTokenProp) {
            netTokenToDeposit = state.totalToken.mulDown(
                (currentTokenProp - targetTokenProp).divDown(currentTokenProp)
            );
        } else {
            uint256 currentSyProp = Math.ONE - currentTokenProp;
            netSyToRedeem = state.totalSy.mulDown(
                (targetTokenProp - currentTokenProp).divDown(currentSyProp)
            );
        }
    }

    function reBalanceTokenToSy(
        BulkSellerState memory state,
        uint256 netTokenToDeposit,
        uint256 netSyFromToken,
        uint256 maxDiff
    ) internal pure {
        uint256 rate = netSyFromToken.divDown(netTokenToDeposit);

        require(Math.isAApproxB(rate, state.rateTokenToSy, maxDiff), "bad rate");

        state.totalToken -= netTokenToDeposit;
        state.totalSy += netSyFromToken;
    }

    function reBalanceSyToToken(
        BulkSellerState memory state,
        uint256 netSyToRedeem,
        uint256 netTokenFromSy,
        uint256 maxDiff
    ) internal pure {
        uint256 rate = netTokenFromSy.divDown(netSyToRedeem);

        require(Math.isAApproxB(rate, state.rateSyToToken, maxDiff), "bad rate");

        state.totalToken += netTokenFromSy;
        state.totalSy -= netSyToRedeem;
    }

    function setRate(
        BulkSellerState memory state,
        uint256 rateTokenToSy,
        uint256 rateSyToToken,
        uint256 maxDiff
    ) internal pure {
        require(Math.isAApproxB(rateSyToToken, state.rateSyToToken, maxDiff), "bad rate");
        require(Math.isAApproxB(rateTokenToSy, state.rateTokenToSy, maxDiff), "bad rate");

        state.rateTokenToSy = rateTokenToSy;
        state.rateSyToToken = rateSyToToken;
    }
}
