// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./FixedPoint.sol";
import "./MarketMathLib.sol";

// solhint-disable reason-string, ordering
library MarketApproxLib {
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using LogExpMath for int256;
    using SCYIndexLib for SCYIndex;
    using MarketMathLib for MarketParameters;

    struct ApproxSwapExactScyForYtSlot {
        uint256 low;
        uint256 high;
        bool isAcceptableAnswerExisted;
        uint256 currentYtOutGuess;
        int256 otToAccount;
        int256 scyReceived;
        int256 totalScyToMintYo;
        int256 netYoFromScy;
        bool isResultAcceptable;
    }

    function approxSwapExactScyForOt(
        MarketParameters memory marketImmutable,
        SCYIndex index,
        uint256 exactScyIn,
        uint256 timeToExpiry,
        uint256 netOtOutGuessMin,
        uint256 netOtOutGuessMax
    ) internal pure returns (uint256 netOtOut) {
        require(exactScyIn > 0, "invalid scy in");
        require(
            netOtOutGuessMin >= 0 && netOtOutGuessMax >= 0 && netOtOutGuessMin <= netOtOutGuessMax,
            "invalid guess"
        );

        uint256 low = netOtOutGuessMin;
        uint256 high = netOtOutGuessMax;
        bool isAcceptableAnswerExisted;

        while (low != high) {
            uint256 currentOtOutGuess = (low + high + 1) / 2;
            MarketParameters memory market = MarketMathLib.deepCloneMarket(marketImmutable);

            (uint256 netScyNeed, ) = market.swapScyForExactOt(
                index,
                currentOtOutGuess,
                timeToExpiry
            );
            bool isResultAcceptable = (netScyNeed <= exactScyIn);
            if (isResultAcceptable) {
                low = currentOtOutGuess;
                isAcceptableAnswerExisted = true;
            } else high = currentOtOutGuess - 1;
        }

        require(isAcceptableAnswerExisted, "guess fail");
        netOtOut = low;
    }

    function approxSwapOtForExactScy(
        MarketParameters memory marketImmutable,
        SCYIndex index,
        uint256 exactScyOut,
        uint256 timeToExpiry,
        uint256 netOtInGuessMin,
        uint256 netOtInGuessMax
    ) internal pure returns (uint256 netOtIn) {
        require(exactScyOut > 0, "invalid scy in");
        require(
            netOtInGuessMin >= 0 && netOtInGuessMax >= 0 && netOtInGuessMin <= netOtInGuessMax,
            "invalid guess"
        );

        uint256 low = netOtInGuessMin;
        uint256 high = netOtInGuessMax;
        bool isAcceptableAnswerExisted;

        while (low != high) {
            uint256 currentOtInGuess = (low + high) / 2;
            MarketParameters memory market = MarketMathLib.deepCloneMarket(marketImmutable);

            (uint256 netScyToAccount, ) = market.swapExactOtForScy(
                index,
                currentOtInGuess,
                timeToExpiry
            );
            bool isResultAcceptable = (netScyToAccount >= exactScyOut);
            if (isResultAcceptable) {
                high = currentOtInGuess;
                isAcceptableAnswerExisted = true;
            } else {
                low = currentOtInGuess + 1;
            }
        }

        require(isAcceptableAnswerExisted, "guess fail");
        netOtIn = high;
    }

    function approxSwapExactScyForYt(
        MarketParameters memory marketImmutable,
        SCYIndex index,
        uint256 exactScyIn,
        uint256 timeToExpiry,
        uint256 netYtOutGuessMin,
        uint256 netYtOutGuessMax
    ) internal pure returns (uint256 netYtOut) {
        require(exactScyIn > 0, "invalid scy in");
        require(netYtOutGuessMin >= 0 && netYtOutGuessMax >= 0, "invalid guess");

        ApproxSwapExactScyForYtSlot memory slot;

        slot.low = netYtOutGuessMin;
        slot.high = netYtOutGuessMax;

        while (slot.low != slot.high) {
            slot.currentYtOutGuess = (slot.low + slot.high + 1) / 2;
            MarketParameters memory market = MarketMathLib.deepCloneMarket(marketImmutable);

            slot.otToAccount = slot.currentYtOutGuess.neg();

            (slot.scyReceived, ) = market.executeTrade(index, slot.otToAccount, timeToExpiry);

            slot.totalScyToMintYo = slot.scyReceived + exactScyIn.Int();

            slot.netYoFromScy = index.scyToAsset(slot.totalScyToMintYo);

            bool isResultAcceptable = (slot.netYoFromScy.Uint() >= slot.currentYtOutGuess);

            if (isResultAcceptable) {
                slot.low = slot.currentYtOutGuess;
                slot.isAcceptableAnswerExisted = true;
            } else slot.high = slot.currentYtOutGuess - 1;
        }

        require(slot.isAcceptableAnswerExisted, "guess fail");
        netYtOut = slot.low;
    }
}
