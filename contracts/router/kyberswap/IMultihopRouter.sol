// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.7.6;

pragma abicoder v2;

interface IMultihopRouter {
    enum DexType {
        UNI,
        STABLESWAP,
        CURVE,
        KYBERDMM,
        SADDLE,
        UNIV3PROMM,
        BALANCERV2,
        KYBERRFQ,
        DODO,
        VELODROME,
        PLATYPUS
    }

    event Exchange(address pair, uint256 amountOut, address output);
    struct Swap {
        bytes data;
        //dexType:
        //  0: uni
        //  1: stable swap
        //  2: curve
        //  3: kyber dmm
        //  4: saddle
        //  5: univ3 or kyber ProMM
        //  6: balancerv2
        //  7: kyber RFQ
        //  8: dodo
        //  9: velodrome
        //  10: platypus
        //dexId:
        //  0: firebird
        uint16 dexOption; //dexType(8bit) + dexId(8bit)
    }

    struct UniSwap {
        address pool;
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 collectAmount; // amount that should be transferred to the pool
        uint256 limitReturnAmount;
    }

    struct StableSwap {
        address pool;
        address tokenFrom;
        address tokenTo;
        uint8 tokenIndexFrom;
        uint8 tokenIndexTo;
        uint256 dx;
        uint256 minDy;
        uint256 poolLength;
        address poolLp;
    }

    struct CurveSwap {
        address pool;
        address tokenFrom;
        address tokenTo;
        int128 tokenIndexFrom;
        int128 tokenIndexTo;
        uint256 dx;
        uint256 minDy;
        bool usePoolUnderlying;
        bool useTriCrypto;
    }

    struct UniSwapV3ProMM {
        address recipient;
        address pool;
        address tokenIn;
        address tokenOut;
        uint256 swapAmount;
        uint256 limitReturnAmount;
        uint160 sqrtPriceLimitX96;
        bool isUniV3; // true = UniV3, false = ProMM
    }
    struct SwapCallbackData {
        bytes path;
        address payer;
    }
    struct SwapCallbackDataPath {
        address pool;
        address tokenIn;
        address tokenOut;
    }

    struct BalancerV2 {
        address vault;
        bytes32 poolId;
        address assetIn;
        address assetOut;
        uint256 amount;
        uint256 limit;
    }

    struct KyberRFQ {
        address rfq;
        bytes order;
        bytes signature;
        uint256 amount;
        address payable target;
    }

    struct DODO {
        address recipient;
        address pool;
        address tokenFrom;
        address tokenTo;
        uint256 amount;
        uint256 minReceiveQuote;
        address sellHelper;
        bool isSellBase;
        bool isVersion2;
    }

    function factory() external view returns (address);

    function formula() external view returns (address);

    function WETH() external view returns (address);

    function multihopBatchSwapExactIn(
        Swap[][] memory swapSequences,
        address tokenIn,
        address tokenOut,
        uint256 minTotalAmountOut,
        address to,
        uint256 deadline,
        bytes memory destTokenFeeData
    ) external payable returns (uint256 totalAmountOut);
}
