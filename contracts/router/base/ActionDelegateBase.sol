// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {ActionBase} from "./ActionBase.sol";
import {IPActionSimple} from "../../interfaces/IPActionSimple.sol";
import {ApproxParams, TokenInput, LimitOrderData} from "../../interfaces/IPAllActionTypeV3.sol";

contract ActionDelegateBase is ActionBase {
    function tryDelegateToAddLiquiditySinglePtSimple(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtSwapToSy,
        LimitOrderData calldata limit
    ) internal returns (bool delegated, uint256 netLpOut, uint256 netSyFee) {
        if (canUseOnchainApproximation(guessPtSwapToSy, limit)) {
            bytes memory res;
            (delegated, res) = _delegateToSelf(
                abi.encodeCall(IPActionSimple.addLiquiditySinglePtSimple, (receiver, market, netPtIn, minLpOut)),
                /* allowFailure= */ false
            );
            assert(delegated);
            (netLpOut, netSyFee) = abi.decode(res, (uint256, uint256));
        }
    }

    function tryDelegateToAddLiquiditySingleTokenSimple(
        address receiver,
        address market,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromSy,
        TokenInput calldata input,
        LimitOrderData calldata limit
    ) internal returns (bool delegated, uint256 netLpOut, uint256 netSyFee, uint256 netSyInterm) {
        if (canUseOnchainApproximation(guessPtReceivedFromSy, limit)) {
            bytes memory res;
            (delegated, res) = _delegateToSelf(
                abi.encodeCall(IPActionSimple.addLiquiditySingleTokenSimple, (receiver, market, minLpOut, input)),
                /* allowFailure= */ false
            );
            assert(delegated);
            (netLpOut, netSyFee, netSyInterm) = abi.decode(res, (uint256, uint256, uint256));
        }
    }

    function tryDelegateToAddLiquiditySingleSySimple(
        address receiver,
        address market,
        uint256 netSyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromSy,
        LimitOrderData calldata limit
    ) internal returns (bool delegated, uint256 netLpOut, uint256 netSyFee) {
        if (canUseOnchainApproximation(guessPtReceivedFromSy, limit)) {
            bytes memory res;
            (delegated, res) = _delegateToSelf(
                abi.encodeCall(IPActionSimple.addLiquiditySingleSySimple, (receiver, market, netSyIn, minLpOut)),
                /* allowFailure= */ false
            );
            assert(delegated);
            (netLpOut, netSyFee) = abi.decode(res, (uint256, uint256));
        }
    }

    function tryDelegateToRemoveLiquiditySinglePtSimple(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minPtOut,
        ApproxParams calldata guessPtReceivedFromSy,
        LimitOrderData calldata limit
    ) internal returns (bool delegated, uint256 netPtOut, uint256 netSyFee) {
        if (canUseOnchainApproximation(guessPtReceivedFromSy, limit)) {
            bytes memory res;
            (delegated, res) = _delegateToSelf(
                abi.encodeCall(
                    IPActionSimple.removeLiquiditySinglePtSimple,
                    (receiver, market, netLpToRemove, minPtOut)
                ),
                /* allowFailure= */ false
            );
            assert(delegated);
            (netPtOut, netSyFee) = abi.decode(res, (uint256, uint256));
        }
    }

    function tryDelegateToSwapExactTokenForPtSimple(
        address receiver,
        address market,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        TokenInput calldata input,
        LimitOrderData calldata limit
    ) internal returns (bool delegated, uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm) {
        if (canUseOnchainApproximation(guessPtOut, limit)) {
            bytes memory res;
            (delegated, res) = _delegateToSelf(
                abi.encodeCall(IPActionSimple.swapExactTokenForPtSimple, (receiver, market, minPtOut, input)),
                /* allowFailure= */ false
            );
            assert(delegated);
            (netPtOut, netSyFee, netSyInterm) = abi.decode(res, (uint256, uint256, uint256));
        }
    }

    function tryDelegateToSwapExactSyForPtSimple(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        LimitOrderData calldata limit
    ) internal returns (bool delegated, uint256 netPtOut, uint256 netSyFee) {
        if (canUseOnchainApproximation(guessPtOut, limit)) {
            bytes memory res;
            (delegated, res) = _delegateToSelf(
                abi.encodeCall(IPActionSimple.swapExactSyForPtSimple, (receiver, market, exactSyIn, minPtOut)),
                /* allowFailure= */ false
            );
            assert(delegated);
            (netPtOut, netSyFee) = abi.decode(res, (uint256, uint256));
        }
    }

    function tryDelegateToSwapExactTokenForYtSimple(
        address receiver,
        address market,
        uint256 minYtOut,
        ApproxParams calldata guessYtOut,
        TokenInput calldata input,
        LimitOrderData calldata limit
    ) internal returns (bool delegated, uint256 netYtOut, uint256 netSyFee, uint256 netSyInterm) {
        if (canUseOnchainApproximation(guessYtOut, limit)) {
            bytes memory res;
            (delegated, res) = _delegateToSelf(
                abi.encodeCall(IPActionSimple.swapExactTokenForYtSimple, (receiver, market, minYtOut, input)),
                /* allowFailure= */ false
            );
            assert(delegated);
            (netYtOut, netSyFee, netSyInterm) = abi.decode(res, (uint256, uint256, uint256));
        }
    }

    function tryDelegateToSwapExactSyForYtSimple(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minYtOut,
        ApproxParams calldata guessYtOut,
        LimitOrderData calldata limit
    ) internal returns (bool delegated, uint256 netYtOut, uint256 netSyFee) {
        if (canUseOnchainApproximation(guessYtOut, limit)) {
            bytes memory res;
            (delegated, res) = _delegateToSelf(
                abi.encodeCall(IPActionSimple.swapExactSyForYtSimple, (receiver, market, exactSyIn, minYtOut)),
                /* allowFailure= */ false
            );
            assert(delegated);
            (netYtOut, netSyFee) = abi.decode(res, (uint256, uint256));
        }
    }

    function canUseOnchainApproximation(
        ApproxParams calldata approx,
        LimitOrderData calldata limit
    ) internal pure returns (bool) {
        return approx.guessOffchain == 0 && _isEmptyLimit(limit);
    }
}
