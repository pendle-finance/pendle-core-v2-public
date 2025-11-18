// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "../interfaces/IPMarket.sol";
import "../router/math/MarketApproxLibOnchain.sol";
import "../router/base/ActionBase.sol";
import "../interfaces/IMarketSweed.sol";

contract MarketSweed is ActionBase, IMarketSweed {
    using PMath for uint256;
    using PMath for int256;
    using PYIndexLib for PYIndex;
    using MarketMathCore for MarketState;
    using PYIndexLib for IPYieldToken;

    struct MarketTokens {
        IStandardizedYield SY;
        IPPrincipalToken PT;
        IPYieldToken YT;
    }

    // solhint-disable no-empty-blocks
    constructor() {}

    function seedAtImpliedRate(
        address receiver,
        address market,
        uint256 minLpOut,
        uint256 minYtOut,
        TokenInput calldata input,
        ApproxSweedParams calldata sweedParams
    ) external payable returns (uint256 netLpOut, uint256 netYtOut, int256 guessedAmountPtToSwap) {
        MarketTokens memory tokens;
        (tokens.SY, tokens.PT, tokens.YT) = IPMarket(market).readTokens();

        _mintSyFromToken(address(this), address(tokens.SY), 1, input);

        uint256 netPtOut;
        (netPtOut, netYtOut, guessedAmountPtToSwap) = _swap(receiver, market, tokens, sweedParams);

        uint256 netYtFromSeed;
        (netLpOut, netYtFromSeed, ) = _seed(receiver, market, tokens, _selfBalance(tokens.SY), netPtOut);
        netYtOut += netYtFromSeed;

        if (netLpOut < minLpOut) revert("Slippage: INSUFFICIENT_LP_OUT");
        if (netYtOut < minYtOut) revert("Slippage: INSUFFICIENT_YT_OUT");
    }

    function mintPYFromToken__noCall(
        address YT,
        TokenInput calldata input
    ) external payable returns (uint256 netPYOut) {
        address SY = IPYieldToken(YT).SY();
        _mintSyFromToken(YT, SY, 1, input);
        netPYOut = IPYieldToken(YT).mintPY(msg.sender, msg.sender);
    }

    function _seed(
        address receiver,
        address market,
        MarketTokens memory tokens,
        uint256 netSyIn,
        uint256 netPtIn
    ) internal returns (uint256 /*netLpOut*/, uint256 /*netYtOut*/, uint256 /*netSyMintPy*/) {
        uint256 netSyMintPy = _calcSyToMintPYSeed(market, tokens, netSyIn, netPtIn);

        // transfer SY to mint PY
        _transferOut(address(tokens.SY), address(tokens.YT), netSyMintPy);
        uint256 netPYMinted = tokens.YT.mintPY(market, receiver);

        // the rest of SY goes to market
        uint256 netSyAddLiquidity = netSyIn - netSyMintPy;
        _transferOut(address(tokens.SY), market, netSyAddLiquidity);
        _transferOut(address(tokens.PT), market, netPtIn);

        (uint256 netLpOut, , ) = IPMarket(market).mint(receiver, netSyAddLiquidity, netPYMinted + netPtIn);
        return (netLpOut, netPYMinted, netSyMintPy);
    }

    function _swap(
        address receiver,
        address market,
        MarketTokens memory tokens,
        ApproxSweedParams memory sweedParams
    ) internal returns (uint256 amountPtToAccount, uint256 amountYTToAccount, int256 guessedSwap) {
        PYIndex index = _getPYIndex(market);
        MarketState memory state = _readMarket(market);
        MarketPreCompute memory comp = state.getMarketPreCompute(index, block.timestamp);

        if (PMath.isAApproxB(state.lastLnImpliedRate, sweedParams.targetLnImpliedRate, sweedParams.eps)) {
            return (0, 0, 0);
        }

        if (state.lastLnImpliedRate > sweedParams.targetLnImpliedRate) {
            // Normalize maxPtToSwap
            sweedParams.maxPtToSwap = PMath.min(
                sweedParams.maxPtToSwap,
                MarketApproxPtOutLibOnchain.calcMaxPtOut(comp, state.totalPt)
            );

            int256 amountSyToAccount;

            (guessedSwap, amountSyToAccount) = _calcAmountPtToBuy(state, index, sweedParams);
            amountPtToAccount = guessedSwap.Uint();

            _transferOut(address(tokens.SY), market, amountSyToAccount.abs());
            IPMarket(market).swapSyForExactPt(address(this), guessedSwap.abs(), EMPTY_BYTES);
        } else {
            // Normalize maxPtToSwap
            sweedParams.maxPtToSwap = PMath.min(
                sweedParams.maxPtToSwap,
                MarketApproxPtInLibOnchain.calcSoftMaxPtIn(state, comp)
            );

            guessedSwap = _calcAmountPtToSell(state, index, sweedParams);

            uint256 amountPtToSell = guessedSwap.neg().Uint();
            amountYTToAccount = amountPtToSell;

            _transferOut(address(tokens.SY), address(tokens.YT), index.assetToSyUp(amountPtToSell));
            uint256 amountPYOut = tokens.YT.mintPY(market, receiver);

            assert(amountPYOut >= amountPtToSell);

            // this amount of SY will be used to add liquidity in later step
            IPMarket(market).swapExactPtForSy(address(this), amountPtToSell, EMPTY_BYTES);
        }
    }

    function _calcAmountPtToBuy(
        MarketState memory state,
        PYIndex index,
        ApproxSweedParams memory sweedParams
    ) internal view returns (int256 amountPtToSwapToAccount, int256 amountSyToAccount) {
        int256 refAmt = sweedParams.maxPtToSwap.Int();
        int256 accPtToAccount = 0;
        MarketState memory localState;

        for (uint256 iter = 0; iter < sweedParams.maxIteration; ++iter) {
            int256 guess;
            if (iter == 0 && _isValidGuessOffchain(sweedParams, true)) {
                guess = sweedParams.guessOffchain;
            } else {
                refAmt /= 2;
                guess = accPtToAccount + refAmt;
            }

            _makeACopyTo(state, localState);
            // Will not revert. maxPtToBuy should already be normalized
            (int256 localAmountSyToAccount, , ) = localState.executeTradeCore(index, guess, block.timestamp);

            if (PMath.isAApproxB(localState.lastLnImpliedRate, sweedParams.targetLnImpliedRate, sweedParams.eps)) {
                return (guess, localAmountSyToAccount);
            }

            if (localState.lastLnImpliedRate > sweedParams.targetLnImpliedRate) {
                accPtToAccount = guess;
            }
        }
        revert("_calcAmountPtToBuy: failed");
    }

    function _calcAmountPtToSell(
        MarketState memory state,
        PYIndex index,
        ApproxSweedParams memory sweedParams
    ) internal view returns (int256 amountPtToSwapToAccount) {
        int256 refAmt = sweedParams.maxPtToSwap.Int();
        int256 accPtToAccount = 0;
        MarketState memory localState;

        for (uint256 iter = 0; iter < sweedParams.maxIteration; ++iter) {
            int256 guess;
            if (iter == 0 && _isValidGuessOffchain(sweedParams, false)) {
                guess = sweedParams.guessOffchain;
            } else {
                refAmt /= 2;
                guess = accPtToAccount - refAmt;
            }

            _makeACopyTo(state, localState);

            // Will not revert. maxPtToSell should already be normalized
            localState.executeTradeCore(index, guess, block.timestamp);

            if (PMath.isAApproxB(localState.lastLnImpliedRate, sweedParams.targetLnImpliedRate, sweedParams.eps)) {
                return guess;
            }

            if (localState.lastLnImpliedRate < sweedParams.targetLnImpliedRate) {
                accPtToAccount = guess;
            }
        }
        revert("_calcAmountPtToSell: failed");
    }

    function _calcSyToMintPYSeed(
        address market,
        MarketTokens memory tokens,
        uint256 netSyIn,
        uint256 netPtIn
    ) internal returns (uint256 /* netSyMintPy */) {
        uint256 netSyMintPy = netSyIn;
        if (netPtIn > 0) {
            (, , uint256 netSyDual, uint256 netPtDual) = _readMarket(market).addLiquidity(
                netSyIn,
                netPtIn,
                block.timestamp
            );
            if (netPtDual < netPtIn) {
                revert("MS: Bought too much PT");
            }
            netSyMintPy -= netSyDual;
        }

        MarketState memory state = _readMarket(market);
        PYIndex pyIndex = tokens.YT.newIndex();
        netSyMintPy =
            (netSyMintPy * state.totalPt.Uint()) /
            (state.totalPt.Uint() + pyIndex.syToAsset(state.totalSy.Uint()));

        return netSyMintPy;
    }

    function _getPYIndex(address market) internal returns (PYIndex) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        return PYIndex.wrap(YT.pyIndexCurrent());
    }

    function _makeACopyTo(MarketState memory state, MarketState memory copiedState) internal pure {
        copiedState.totalPt = state.totalPt;
        copiedState.totalSy = state.totalSy;
        copiedState.totalLp = state.totalLp;
        copiedState.treasury = state.treasury;

        copiedState.scalarRoot = state.scalarRoot;
        copiedState.expiry = state.expiry;

        copiedState.lnFeeRateRoot = state.lnFeeRateRoot;
        copiedState.reserveFeePercent = state.reserveFeePercent;
        copiedState.lastLnImpliedRate = state.lastLnImpliedRate;
    }

    function _isValidGuessOffchain(ApproxSweedParams memory sweedParams, bool isBuyingPt) internal pure returns (bool) {
        if (sweedParams.guessOffchain == 0) return false;
        if (isBuyingPt != (sweedParams.guessOffchain > 0)) return false;
        return sweedParams.guessOffchain.abs() <= sweedParams.maxPtToSwap;
    }
}
