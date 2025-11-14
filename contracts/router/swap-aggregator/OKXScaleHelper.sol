// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../core/libraries/TokenHelper.sol";
import "./IPSwapAggregator.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract OKXScaleHelper {
    address public immutable _tokenApprove;
    uint256 internal constant TRIM_FLAG_MASK = 0xffffffffffff0000000000000000000000000000000000000000000000000000;
    uint256 internal constant TRIM_FLAG = 0x7777777711110000000000000000000000000000000000000000000000000000;
    uint256 internal constant TRIM_DUAL_FLAG = 0x7777777722220000000000000000000000000000000000000000000000000000;
    uint256 internal constant TRIM_EXPECT_AMOUNT_OUT_MASK =
        0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    // @dev `allowUnsupportedChain` is a safe guard to prevent deploying this contract on unsupported chains by mistake
    // @dev Please add new `__getTokenApproveForChain` entry when deploying to a new chain.
    constructor(bool allowUnsupportedChain) {
        _tokenApprove = __getTokenApproveForChain(block.chainid);
        if (!allowUnsupportedChain) {
            require(_tokenApprove != address(0), "PendleSwap: OKX chain not supported");
        }
    }

    // https://web3.okx.com/build/dev-docs/dex-api/dex-smart-contract#token-approval
    function __getTokenApproveForChain(uint256 chainid) private pure returns (address) {
        if (chainid == 1) {
            return 0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f;
        }
        if (chainid == 10) {
            return 0x68D6B739D2020067D1e2F713b999dA97E4d54812;
        }
        if (chainid == 56) {
            return 0x2c34A2Fb1d0b4f55de51E1d0bDEfaDDce6b7cDD6;
        }
        if (chainid == 42_161) {
            return 0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58;
        }
        if (chainid == 8453 || chainid == 5000) {
            return 0x57df6092665eb6058DE53939612413ff4B09114E;
        }
        if (chainid == 146) {
            return 0xD321ab5589d3E8FA5Df985ccFEf625022E2DD910;
        }
        if (chainid == 9745) {
            return 0x9FD43F5E4c24543b2eBC807321E58e6D350d6a5A;
        }
        return address(0);
    }

    function _okx_getTokenApprove() internal view returns (address) {
        require(_tokenApprove != address(0), "PendleSwap: OKX chain not supported");
        return _tokenApprove;
    }

    function _okxScaling(bytes calldata rawCallData, uint256 actualAmount)
        internal
        pure
        returns (bytes memory scaledCallData)
    {
        bytes4 selector = bytes4(rawCallData[:4]);
        bytes calldata dataToDecode = rawCallData[4:];
        uint256 rawAmountIn;
        if (selector == IOKXDexRouter.uniswapV3SwapTo.selector) {
            (uint256 receiver, uint256 amount, uint256 minReturn, uint256[] memory pools) =
                abi.decode(dataToDecode, (uint256, uint256, uint256, uint256[]));
            rawAmountIn = amount;
            minReturn = (minReturn * actualAmount) / amount;
            amount = actualAmount;

            scaledCallData = abi.encodeWithSelector(selector, receiver, amount, minReturn, pools);
        } else if (selector == IOKXDexRouter.smartSwapTo.selector) {
            (
                uint256 orderId,
                address receiver,
                IOKXDexRouter.BaseRequest memory baseRequest,
                uint256[] memory batchesAmount,
                IOKXDexRouter.RouterPath[][] memory batches,
                IOKXDexRouter.PMMSwapRequest[] memory extraData
            ) = abi.decode(
                dataToDecode,
                (
                    uint256,
                    address,
                    IOKXDexRouter.BaseRequest,
                    uint256[],
                    IOKXDexRouter.RouterPath[][],
                    IOKXDexRouter.PMMSwapRequest[]
                )
            );
            rawAmountIn = baseRequest.fromTokenAmount;
            batchesAmount = _scaleArray(batchesAmount, actualAmount, baseRequest.fromTokenAmount);
            baseRequest.minReturnAmount = (baseRequest.minReturnAmount * actualAmount) / baseRequest.fromTokenAmount;
            baseRequest.fromTokenAmount = actualAmount;

            scaledCallData =
                abi.encodeWithSelector(selector, orderId, receiver, baseRequest, batchesAmount, batches, extraData);
        } else if (selector == IOKXDexRouter.unxswapTo.selector) {
            (uint256 srcToken, uint256 amount, uint256 minReturn, address receiver, bytes32[] memory pools) =
                abi.decode(dataToDecode, (uint256, uint256, uint256, address, bytes32[]));

            minReturn = (minReturn * actualAmount) / amount;
            rawAmountIn = amount;
            amount = actualAmount;

            scaledCallData = abi.encodeWithSelector(selector, srcToken, amount, minReturn, receiver, pools);
        } else if (selector == IOKXDexRouter.unxswapByOrderId.selector) {
            (uint256 srcToken, uint256 amount, uint256 minReturn, bytes32[] memory pools) =
                abi.decode(dataToDecode, (uint256, uint256, uint256, bytes32[]));
            rawAmountIn = amount;

            minReturn = (minReturn * actualAmount) / amount;
            amount = actualAmount;

            scaledCallData = abi.encodeWithSelector(selector, srcToken, amount, minReturn, pools);
        } else if (selector == IOKXDexRouter.smartSwapByOrderId.selector) {
            (
                uint256 orderId,
                IOKXDexRouter.BaseRequest memory baseRequest,
                uint256[] memory batchesAmount,
                IOKXDexRouter.RouterPath[][] memory batches,
                IOKXDexRouter.PMMSwapRequest[] memory extraData
            ) = abi.decode(
                dataToDecode,
                (
                    uint256,
                    IOKXDexRouter.BaseRequest,
                    uint256[],
                    IOKXDexRouter.RouterPath[][],
                    IOKXDexRouter.PMMSwapRequest[]
                )
            );
            rawAmountIn = baseRequest.fromTokenAmount;
            batchesAmount = _scaleArray(batchesAmount, actualAmount, baseRequest.fromTokenAmount);
            baseRequest.minReturnAmount = (baseRequest.minReturnAmount * actualAmount) / baseRequest.fromTokenAmount;
            baseRequest.fromTokenAmount = actualAmount;

            scaledCallData = abi.encodeWithSelector(selector, orderId, baseRequest, batchesAmount, batches, extraData);
        } else if (selector == IOKXDexRouter.dagSwapTo.selector) {
            (
                uint256 orderId,
                address receiver,
                IOKXDexRouter.BaseRequest memory baseRequest,
                IOKXDexRouter.RouterPath[] memory paths
            ) = abi.decode(dataToDecode, (uint256, address, IOKXDexRouter.BaseRequest, IOKXDexRouter.RouterPath[]));

            rawAmountIn = baseRequest.fromTokenAmount;
            baseRequest.minReturnAmount = (baseRequest.minReturnAmount * actualAmount) / baseRequest.fromTokenAmount;
            baseRequest.fromTokenAmount = actualAmount;

            scaledCallData = abi.encodeWithSelector(selector, orderId, receiver, baseRequest, paths);
        } else if (selector == IOKXDexRouter.dagSwapByOrderId.selector) {
            (uint256 orderId, IOKXDexRouter.BaseRequest memory baseRequest, IOKXDexRouter.RouterPath[] memory paths) =
                abi.decode(dataToDecode, (uint256, IOKXDexRouter.BaseRequest, IOKXDexRouter.RouterPath[]));
            rawAmountIn = baseRequest.fromTokenAmount;
            baseRequest.minReturnAmount = (baseRequest.minReturnAmount * actualAmount) / baseRequest.fromTokenAmount;
            baseRequest.fromTokenAmount = actualAmount;

            scaledCallData = abi.encodeWithSelector(selector, orderId, baseRequest, paths);
        } else {
            revert("PendleSwap: OKX selector not supported");
        }

        scaledCallData = _scaleTrimInfo(rawCallData, scaledCallData, actualAmount, rawAmountIn);
        return scaledCallData;
    }

    function _scaleArray(uint256[] memory arr, uint256 newAmount, uint256 oldAmount)
        internal
        pure
        returns (uint256[] memory scaledArr)
    {
        scaledArr = new uint256[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            scaledArr[i] = (arr[i] * newAmount) / oldAmount;
        }
    }

    function _scaleTrimInfo(
        bytes calldata rawCallData,
        bytes memory scaledCallData,
        uint256 actualAmountIn,
        uint256 rawAmountIn
    ) internal pure returns (bytes memory) {
        bytes memory tail = rawCallData[scaledCallData.length:];
        // search trim flag from back to front, get the index
        assembly {
            let endPtr := add(add(tail, 32), mload(tail))
            let startPtr := add(tail, 32)
            let shown := 0

            for { let i := sub(endPtr, 32) } or(gt(i, startPtr), eq(i, startPtr)) { i := sub(i, 32) } {
                let data := mload(i)
                if or(eq(and(data, TRIM_FLAG_MASK), TRIM_FLAG), eq(and(data, TRIM_FLAG_MASK), TRIM_DUAL_FLAG)) {
                    shown := add(shown, 1)
                    if eq(shown, 2) {
                        let expectAmountOut := and(data, TRIM_EXPECT_AMOUNT_OUT_MASK)
                        let acutalExpectAmountOut := mul(expectAmountOut, actualAmountIn)
                        acutalExpectAmountOut := div(acutalExpectAmountOut, rawAmountIn)
                        acutalExpectAmountOut := and(acutalExpectAmountOut, TRIM_EXPECT_AMOUNT_OUT_MASK)
                        data := and(data, not(TRIM_EXPECT_AMOUNT_OUT_MASK))
                        data := or(data, acutalExpectAmountOut)
                        mstore(i, data)
                        break
                    }
                }
            }
        }
        scaledCallData = bytes.concat(scaledCallData, tail);
        return scaledCallData;
    }
}

interface IOKXDexRouter {
    struct BaseRequest {
        uint256 fromToken;
        address toToken;
        uint256 fromTokenAmount;
        uint256 minReturnAmount;
        uint256 deadLine;
    }

    struct RouterPath {
        address[] mixAdapters;
        address[] assetTo;
        uint256[] rawData;
        bytes[] extraData;
        uint256 fromToken;
    }

    struct PMMSwapRequest {
        uint256 pathIndex;
        address payer;
        address fromToken;
        address toToken;
        uint256 fromTokenAmountMax;
        uint256 toTokenAmountMax;
        uint256 salt;
        uint256 deadLine;
        bool isPushOrder;
        bytes extension;
    }

    // // address marketMaker;
    // // uint256 subIndex;
    // // bytes signature;
    // // uint256 source;  1byte type + 1byte bool（reverse） + 0...0 + 20 bytes address

    // function smartSwapByInvest(
    //     BaseRequest calldata baseRequest,
    //     uint256[] calldata batchesAmount,
    //     RouterPath[][] calldata batches,
    //     PMMSwapRequest[] calldata extraData,
    //     address to
    // ) external payable;

    function uniswapV3SwapTo(uint256 receiver, uint256 amount, uint256 minReturn, uint256[] calldata pools)
        external
        payable
        returns (uint256 returnAmount);

    function smartSwapTo(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest,
        uint256[] calldata batchesAmount,
        RouterPath[][] calldata batches,
        PMMSwapRequest[] calldata extraData
    ) external payable;

    function unxswapTo(
        uint256 srcToken,
        uint256 amount,
        uint256 minReturn,
        address receiver,
        // solhint-disable-next-line no-unused-vars
        bytes32[] calldata pools
    ) external payable returns (uint256 returnAmount);

    function unxswapByOrderId(
        uint256 srcToken,
        uint256 amount,
        uint256 minReturn,
        // solhint-disable-next-line no-unused-vars
        bytes32[] calldata pools
    ) external payable returns (uint256 returnAmount);

    function smartSwapByOrderId(
        uint256 orderId,
        BaseRequest calldata baseRequest,
        uint256[] calldata batchesAmount,
        RouterPath[][] calldata batches,
        PMMSwapRequest[] calldata extraData
    ) external payable returns (uint256 returnAmount);

    function dagSwapTo(uint256 orderId, address receiver, BaseRequest calldata baseRequest, RouterPath[] calldata paths)
        external
        payable
        returns (uint256 returnAmount);

    function dagSwapByOrderId(uint256 orderId, BaseRequest calldata baseRequest, RouterPath[] calldata paths)
        external
        payable
        returns (uint256 returnAmount);
}
