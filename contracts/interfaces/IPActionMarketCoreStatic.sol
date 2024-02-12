// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPActionMarketCoreStatic {
    function addLiquidityDualSyAndPtStatic(
        address market,
        uint256 netSyDesired,
        uint256 netPtDesired
    ) external view returns (uint256 netLpOut, uint256 netSyUsed, uint256 netPtUsed);

    function addLiquidityDualTokenAndPtStatic(
        address market,
        address tokenIn,
        uint256 netTokenDesired,
        uint256 netPtDesired
    )
        external
        view
        returns (uint256 netLpOut, uint256 netTokenUsed, uint256 netPtUsed, uint256 netSyUsed, uint256 netSyDesired);

    function addLiquiditySinglePtStatic(
        address market,
        uint256 netPtIn
    )
        external
        view
        returns (
            uint256 netLpOut,
            uint256 netPtToSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            uint256 netSyFromSwap
        );

    function addLiquiditySingleSyKeepYtStatic(
        address market,
        uint256 netSyIn
    ) external view returns (uint256 netLpOut, uint256 netYtOut, uint256 netSyToPY);

    function addLiquiditySingleSyStatic(
        address market,
        uint256 netSyIn
    )
        external
        view
        returns (
            uint256 netLpOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            uint256 netSyToSwap
        );

    function addLiquiditySingleTokenKeepYtStatic(
        address market,
        address tokenIn,
        uint256 netTokenIn
    ) external view returns (uint256 netLpOut, uint256 netYtOut, uint256 netSyMinted, uint256 netSyToPY);

    function addLiquiditySingleTokenStatic(
        address market,
        address tokenIn,
        uint256 netTokenIn
    )
        external
        view
        returns (
            uint256 netLpOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            uint256 netSyMinted,
            uint256 netSyToSwap
        );

    function removeLiquidityDualSyAndPtStatic(
        address market,
        uint256 netLpToRemove
    ) external view returns (uint256 netSyOut, uint256 netPtOut);

    function removeLiquidityDualTokenAndPtStatic(
        address market,
        uint256 netLpToRemove,
        address tokenOut
    ) external view returns (uint256 netTokenOut, uint256 netPtOut, uint256 netSyToRedeem);

    function removeLiquiditySinglePtStatic(
        address market,
        uint256 netLpToRemove
    )
        external
        view
        returns (
            uint256 netPtOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            uint256 netSyFromBurn,
            uint256 netPtFromBurn
        );

    function removeLiquiditySingleSyStatic(
        address market,
        uint256 netLpToRemove
    )
        external
        view
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            uint256 netSyFromBurn,
            uint256 netPtFromBurn,
            uint256 netSyFromSwap
        );

    function removeLiquiditySingleTokenStatic(
        address market,
        uint256 netLpToRemove,
        address tokenOut
    )
        external
        view
        returns (
            uint256 netTokenOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            uint256 netSyOut,
            uint256 netSyFromBurn,
            uint256 netPtFromBurn,
            uint256 netSyFromSwap
        );

    function swapExactPtForSyStatic(
        address market,
        uint256 exactPtIn
    ) external view returns (uint256 netSyOut, uint256 netSyFee, uint256 priceImpact, uint256 exchangeRateAfter);

    function swapExactPtForTokenStatic(
        address market,
        uint256 exactPtIn,
        address tokenOut
    )
        external
        view
        returns (
            uint256 netTokenOut,
            uint256 netSyToRedeem,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        );

    function swapExactPtForYtStatic(
        address market,
        uint256 exactPtIn
    )
        external
        view
        returns (
            uint256 netYtOut,
            uint256 totalPtToSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        );

    function swapExactSyForPtStatic(
        address market,
        uint256 exactSyIn
    ) external view returns (uint256 netPtOut, uint256 netSyFee, uint256 priceImpact, uint256 exchangeRateAfter);

    function swapExactSyForYtStatic(
        address market,
        uint256 exactSyIn
    ) external view returns (uint256 netYtOut, uint256 netSyFee, uint256 priceImpact, uint256 exchangeRateAfter);

    function swapExactTokenForPtStatic(
        address market,
        address tokenIn,
        uint256 amountTokenIn
    )
        external
        view
        returns (
            uint256 netPtOut,
            uint256 netSyMinted,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        );

    function swapExactTokenForYtStatic(
        address market,
        address tokenIn,
        uint256 amountTokenIn
    )
        external
        view
        returns (
            uint256 netYtOut,
            uint256 netSyMinted,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        );

    function swapExactYtForPtStatic(
        address market,
        uint256 exactYtIn
    )
        external
        view
        returns (
            uint256 netPtOut,
            uint256 totalPtSwapped,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        );

    function swapExactYtForSyStatic(
        address market,
        uint256 exactYtIn
    )
        external
        view
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            uint256 netSyOwedInt,
            uint256 netPYToRepaySyOwedInt,
            uint256 netPYToRedeemSyOutInt
        );

    function swapExactYtForTokenStatic(
        address market,
        uint256 exactYtIn,
        address tokenOut
    )
        external
        view
        returns (
            uint256 netTokenOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            uint256 netSyOut,
            uint256 netSyOwedInt,
            uint256 netPYToRepaySyOwedInt,
            uint256 netPYToRedeemSyOutInt
        );

    function swapPtForExactSyStatic(
        address market,
        uint256 exactSyOut
    ) external view returns (uint256 netPtIn, uint256 netSyFee, uint256 priceImpact, uint256 exchangeRateAfter);

    function swapSyForExactPtStatic(
        address market,
        uint256 exactPtOut
    ) external view returns (uint256 netSyIn, uint256 netSyFee, uint256 priceImpact, uint256 exchangeRateAfter);

    function swapSyForExactYtStatic(
        address market,
        uint256 exactYtOut
    )
        external
        view
        returns (
            uint256 netSyIn,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            uint256 netSyReceivedInt,
            uint256 totalSyNeedInt
        );

    function swapYtForExactSyStatic(
        address market,
        uint256 exactSyOut
    ) external view returns (uint256 netYtIn, uint256 netSyFee, uint256 priceImpact, uint256 exchangeRateAfter);
}
