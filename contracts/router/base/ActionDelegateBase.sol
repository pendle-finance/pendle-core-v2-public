// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {ActionBase} from "./ActionBase.sol";
import {IPActionSimple} from "../../interfaces/IPActionSimple.sol";
import {ApproxParams, TokenInput, LimitOrderData} from "../../interfaces/IPAllActionTypeV3.sol";

contract ActionDelegateBase is ActionBase {
    function delegateToAddLiquiditySinglePtSimple(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 minLpOut
    ) internal returns (uint256 netLpOut, uint256 netSyFee) {
        (bool success, bytes memory res) = _delegateToSelf(
            abi.encodeCall(IPActionSimple.addLiquiditySinglePtSimple, (receiver, market, netPtIn, minLpOut)),
            /* allowFailure= */ false
        );
        assert(success);
        return abi.decode(res, (uint256, uint256));
    }

    function delegateToAddLiquiditySingleTokenSimple(
        address receiver,
        address market,
        uint256 minLpOut,
        TokenInput calldata input
    ) internal returns (uint256 netLpOut, uint256 netSyFee, uint256 netSyInterm) {
        (bool success, bytes memory res) = _delegateToSelf(
            abi.encodeCall(IPActionSimple.addLiquiditySingleTokenSimple, (receiver, market, minLpOut, input)),
            /* allowFailure= */ false
        );
        assert(success);
        return abi.decode(res, (uint256, uint256, uint256));
    }

    function delegateToAddLiquiditySingleSySimple(
        address receiver,
        address market,
        uint256 netSyIn,
        uint256 minLpOut
    ) internal returns (uint256 netLpOut, uint256 netSyFee) {
        (bool success, bytes memory res) = _delegateToSelf(
            abi.encodeCall(IPActionSimple.addLiquiditySingleSySimple, (receiver, market, netSyIn, minLpOut)),
            /* allowFailure= */ false
        );
        assert(success);
        return abi.decode(res, (uint256, uint256));
    }

    function delegateToRemoveLiquiditySinglePtSimple(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minPtOut
    ) internal returns (uint256 netPtOut, uint256 netSyFee) {
        (bool success, bytes memory res) = _delegateToSelf(
            abi.encodeCall(IPActionSimple.removeLiquiditySinglePtSimple, (receiver, market, netLpToRemove, minPtOut)),
            /* allowFailure= */ false
        );
        assert(success);
        return abi.decode(res, (uint256, uint256));
    }

    function delegateToSwapExactTokenForPtSimple(
        address receiver,
        address market,
        uint256 minPtOut,
        TokenInput calldata input
    ) internal returns (uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm) {
        (bool success, bytes memory res) = _delegateToSelf(
            abi.encodeCall(IPActionSimple.swapExactTokenForPtSimple, (receiver, market, minPtOut, input)),
            /* allowFailure= */ false
        );
        assert(success);
        return abi.decode(res, (uint256, uint256, uint256));
    }

    function delegateToSwapExactSyForPtSimple(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minPtOut
    ) internal returns (uint256 netPtOut, uint256 netSyFee) {
        (bool success, bytes memory res) = _delegateToSelf(
            abi.encodeCall(IPActionSimple.swapExactSyForPtSimple, (receiver, market, exactSyIn, minPtOut)),
            /* allowFailure= */ false
        );
        assert(success);
        return abi.decode(res, (uint256, uint256));
    }

    function delegateToSwapExactTokenForYtSimple(
        address receiver,
        address market,
        uint256 minYtOut,
        TokenInput calldata input
    ) internal returns (uint256 netYtOut, uint256 netSyFee, uint256 netSyInterm) {
        (bool success, bytes memory res) = _delegateToSelf(
            abi.encodeCall(IPActionSimple.swapExactTokenForYtSimple, (receiver, market, minYtOut, input)),
            /* allowFailure= */ false
        );
        assert(success);
        return abi.decode(res, (uint256, uint256, uint256));
    }

    function delegateToSwapExactSyForYtSimple(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minYtOut
    ) internal returns (uint256 netYtOut, uint256 netSyFee) {
        (bool success, bytes memory res) = _delegateToSelf(
            abi.encodeCall(IPActionSimple.swapExactSyForYtSimple, (receiver, market, exactSyIn, minYtOut)),
            /* allowFailure= */ false
        );
        assert(success);
        return abi.decode(res, (uint256, uint256));
    }

    function canUseOnchainApproximation(
        ApproxParams calldata approx,
        LimitOrderData calldata limit
    ) internal pure returns (bool) {
        return approx.guessOffchain == 0 && _isEmptyLimit(limit);
    }
}
