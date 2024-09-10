// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IPMarket} from "../../interfaces/IPMarket.sol";
import {IStandardizedYield} from "../../interfaces/IStandardizedYield.sol";

import {TokenHelper} from "../../core/libraries/TokenHelper.sol";
import {PYIndexLib, IPYieldToken, PYIndex} from "../../core/StandardizedYield/PYIndex.sol";
import {MarketState} from "../../core/Market/MarketMathCore.sol";

import {emptyApproxParams} from "./ApproxParams.sol";
import {CallbackHelper} from "./CallbackHelper.sol";
import {MarketApproxPtInLibV2, MarketApproxPtOutLibV2} from "./MarketApproxLibV2.sol";

abstract contract ActionBaseSimple is TokenHelper, CallbackHelper {
    using MarketApproxPtInLibV2 for MarketState;
    using MarketApproxPtOutLibV2 for MarketState;
    using PYIndexLib for IPYieldToken;
    using PYIndexLib for PYIndex;

    function _swapExactSyForPtSimple(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minPtOut
    ) internal returns (uint256 netPtOut, uint256 netSyFee) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        uint256 netSyLeft = exactSyIn;

        (uint256 netPtOutMarket, , ) = __readMarket(market).approxSwapExactSyForPt(
            YT.newIndex(),
            netSyLeft,
            block.timestamp,
            emptyApproxParams()
        );

        (, uint256 netSyFeeMarket) = IPMarket(market).swapSyForExactPt(receiver, netPtOutMarket, "");

        netPtOut += netPtOutMarket;
        netSyFee += netSyFeeMarket;

        if (netPtOut < minPtOut) revert("Slippage: INSUFFICIENT_PT_OUT");
    }

    function _swapExactSyForYtSimple(
        address receiver,
        address market,
        IStandardizedYield /* SY */,
        IPYieldToken YT,
        uint256 exactSyIn,
        uint256 minYtOut
    ) internal returns (uint256 netYtOut, uint256 netSyFee) {
        uint256 netSyLeft = exactSyIn;

        (uint256 netYtOutMarket, , ) = __readMarket(market).approxSwapExactSyForYt(
            YT.newIndex(),
            netSyLeft,
            block.timestamp,
            emptyApproxParams()
        );

        (, uint256 netSyFeeMarket) = IPMarket(market).swapExactPtForSy(
            address(YT),
            netYtOutMarket, // exactPtIn = netYtOut
            _encodeSwapExactSyForYt(receiver, YT)
        );

        netYtOut += netYtOutMarket;
        netSyFee += netSyFeeMarket;

        if (netYtOut < minYtOut) revert("Slippage: INSUFFICIENT_YT_OUT");
    }

    function _swapExactPtForSySimple(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minSyOut
    ) internal returns (uint256 netSyOut, uint256 netSyFee) {
        uint256 netPtLeft = exactPtIn;

        (uint256 netSyOutMarket, uint256 netSyFeeMarket) = IPMarket(market).swapExactPtForSy(receiver, netPtLeft, "");

        netSyOut += netSyOutMarket;
        netSyFee += netSyFeeMarket;

        if (netSyOut < minSyOut) revert("Slippage: INSUFFICIENT_SY_OUT");
    }

    // ----------------- HELPER -----------------

    function __readMarket(address market) private view returns (MarketState memory) {
        return IPMarket(market).readState(address(this));
    }
}
