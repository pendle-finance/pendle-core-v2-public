pragma solidity ^0.8.0;

import {IKyberDSLO} from "./pools/IKyberDSLO.sol";
import {IKyberLO} from "./pools/IKyberLO.sol";

interface IExecutorHelperL2Struct {
    struct Swap {
        bytes data;
        bytes4 functionSelector;
    }

    struct SwapExecutorDescription {
        Swap[][] swapSequences;
        address tokenIn;
        address tokenOut;
        uint256 minTotalAmountOut;
        address to;
        uint256 deadline;
        bytes positiveSlippageData;
    }

    struct UniSwap {
        address pool;
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 collectAmount; // amount that should be transferred to the pool
        uint32 swapFee;
        uint32 feePrecision;
        uint32 tokenWeightInput;
    }

    struct StableSwap {
        address pool;
        address tokenFrom;
        address tokenTo;
        uint8 tokenIndexFrom;
        uint8 tokenIndexTo;
        uint256 dx;
        uint256 poolLength;
        address poolLp;
        bool isSaddle; // true: saddle, false: stable
    }

    struct CurveSwap {
        address pool;
        address tokenFrom;
        address tokenTo;
        int128 tokenIndexFrom;
        int128 tokenIndexTo;
        uint256 dx;
        bool usePoolUnderlying;
        bool useTriCrypto;
    }

    struct UniswapV3KSElastic {
        address recipient;
        address pool;
        address tokenIn;
        address tokenOut;
        uint256 swapAmount;
        uint160 sqrtPriceLimitX96;
        bool isUniV3; // true = UniV3, false = KSElastic
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
    }

    struct DODO {
        address recipient;
        address pool;
        address tokenFrom;
        address tokenTo;
        uint256 amount;
        address sellHelper;
        bool isSellBase;
        bool isVersion2;
    }

    struct GMX {
        address vault;
        address tokenIn;
        address tokenOut;
        uint256 amount;
        address receiver;
    }

    struct Synthetix {
        address synthetixProxy;
        address tokenIn;
        address tokenOut;
        bytes32 sourceCurrencyKey;
        uint256 sourceAmount;
        bytes32 destinationCurrencyKey;
        bool useAtomicExchange;
    }

    struct WSTETH {
        address pool;
        uint256 amount;
        bool isWrapping;
    }

    struct Platypus {
        address pool;
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 collectAmount; // amount that should be transferred to the pool
    }

    struct PSM {
        address router;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        address recipient;
    }

    struct Maverick {
        address pool;
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 swapAmount;
        uint256 sqrtPriceLimitD18;
    }

    /// @notice Struct for Sync Swap
    /// @param _data encode of (address, address, uint8) : (tokenIn, recipient, withdrawMode)
    ///  Withdraw with mode.
    // 0 = DEFAULT
    // 1 = UNWRAPPED
    // 2 = WRAPPED
    /// @param vault vault contract
    /// @param tokenIn token input to swap
    /// @param pool pool of SyncSwap
    /// @param collectAmount amount that should be transferred to the pool
    struct SyncSwap {
        bytes _data;
        address vault;
        address tokenIn;
        address pool;
        uint256 collectAmount;
    }

    struct AlgebraV1 {
        address recipient;
        address pool;
        address tokenIn;
        address tokenOut;
        uint256 swapAmount;
        uint160 sqrtPriceLimitX96;
        uint256 senderFeeOnTransfer; // [ FoT_FLAG(1 bit) ... SENDER_ADDRESS(160 bits) ]
    }

    struct BalancerBatch {
        address vault;
        bytes32[] poolIds;
        address[] path; // swap path from assetIn to assetOut
        bytes[] userDatas;
        uint256 amountIn; // assetIn amount
    }

    struct Mantis {
        address pool;
        address tokenIn;
        address tokenOut;
        uint256 amount;
        address recipient;
    }

    struct IziSwap {
        address pool;
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 swapAmount;
        int24 limitPoint;
    }

    struct TraderJoeV2 {
        address recipient;
        address pool;
        address tokenIn;
        address tokenOut;
        uint256 collectAmount; // most significant 1 bit is to determine whether pool is v2.0, else v2.1
    }

    struct LevelFiV2 {
        address pool;
        address fromToken;
        address toToken;
        uint256 amountIn;
        uint256 minAmountOut;
        address recipient; // receive token out
    }

    struct GMXGLP {
        address rewardRouter;
        address stakedGLP;
        address glpManager;
        address yearnVault;
        address tokenIn;
        address tokenOut;
        uint256 swapAmount;
        address recipient;
    }

    struct Vooi {
        address pool;
        address fromToken;
        address toToken;
        uint256 fromID;
        uint256 toID;
        uint256 fromAmount;
        address to;
    }

    struct VelocoreV2 {
        address vault;
        uint256 amount;
        address tokenIn;
        address tokenOut;
        address stablePool; // if not empty then use stable pool
        address wrapToken;
        bool isConvertFirst;
    }

    struct MaticMigrate {
        address pool;
        address tokenAddress; // should be POL
        uint256 amount;
        address recipient; // empty if migrate
    }

    struct Kokonut {
        address pool;
        uint256 dx;
        uint256 tokenIndexFrom;
        address fromToken;
        address toToken;
    }

    struct BalancerV1 {
        address pool;
        uint256 amount;
        address tokenIn;
        address tokenOut;
    }

    struct ArbswapStable {
        address pool;
        uint256 dx;
        uint256 tokenIndexFrom;
        address tokenIn;
        address tokenOut;
    }

    struct BancorV2 {
        address pool;
        address[] swapPath;
        uint256 amount;
        address recipient;
    }

    struct Ambient {
        address pool;
        uint128 qty;
        address base;
        address quote;
        uint256 poolIdx;
        uint8 settleFlags;
    }

    struct LighterV2 {
        address orderBook;
        uint256 amount;
        bool isAsk; // isAsk = orderBook.isAskOrder(orderId);
        address tokenIn;
        address tokenOut;
        address recipient;
    }

    struct FrxETH {
        address pool;
        uint256 amount;
        address tokenOut;
    }

    struct RFQTQuote {
        address pool;
        address externalAccount;
        address trader;
        address effectiveTrader;
        address baseToken;
        address quoteToken;
        uint256 effectiveBaseTokenAmount;
        uint256 baseTokenAmount;
        uint256 quoteTokenAmount;
        uint256 quoteExpiry;
        uint256 nonce;
        bytes32 txid;
        bytes signature;
    }

    struct Hashflow {
        address router;
        RFQTQuote quote;
    }

    struct OrderRFQ {
        // lowest 64 bits is the order id, next 64 bits is the expiration timestamp
        // highest bit is unwrap WETH flag which is set on taker's side
        // [unwrap eth(1 bit) | unused (127 bits) | expiration timestamp(64 bits) | orderId (64 bits)]
        uint256 info;
        address makerAsset;
        address takerAsset;
        address maker;
        address allowedSender; // null address on public orders
        uint256 makingAmount;
        uint256 takingAmount;
    }

    struct KyberRFQ {
        address rfq;
        OrderRFQ order;
        bytes signature;
        uint256 amount;
        address payable target;
    }

    struct Native {
        address target; // txRequest.target from api result
        uint256 amount; // should equal which amount_wei from api request
        bytes data; // txRequest.calldata from api result
        address tokenIn;
        address tokenOut;
        address recipient; // should equal which to_address from api request
        uint256 multihopAndOffset; // [1 bytes multihop + 127 bytes empty + 64 bytes amountInOffset + 64 bytes amountOutMinOffset]
    }

    struct KyberDSLO {
        address kyberLOAddress;
        address makerAsset;
        address takerAsset;
        IKyberDSLO.FillBatchOrdersParams params;
    }

    struct Bebop {
        address pool;
        uint256 amount;
        bytes data;
        address tokenIn;
        address tokenOut;
        address recipient;
    }

    struct KyberLimitOrder {
        address kyberLOAddress;
        address makerAsset;
        address takerAsset;
        IKyberLO.FillBatchOrdersParams params;
    }

    struct Kelp {
        address pool;
        uint256 amount;
        address tokenIn;
        address tokenOut;
    }

    struct SymbioticLRT {
        address vault;
        uint256 amount;
        address tokenIn;
        address recipient;
        bool isVer0;
    }

    struct MaverickV2 {
        address pool;
        uint256 collectAmount; // amount that should be transferred to the pool
        address tokenIn; // not encode for l2
        address tokenOut; // not encode for l2
        address recipient;
    }

    struct Integral {
        address pool;
        uint256 collectAmount;
        address tokenIn; // remove for L2
        address tokenOut;
        address recipient;
    }
}
