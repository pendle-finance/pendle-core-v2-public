// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../core/libraries/TokenHelper.sol";
import "./IPSwapAggregator.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract OKXScaleHelper {
    function _okx_getTokenApprove() internal view returns (address) {
        if (block.chainid == 1) {
            return 0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f;
        }
        if (block.chainid == 10) {
            return 0x68D6B739D2020067D1e2F713b999dA97E4d54812;
        }
        if (block.chainid == 56) {
            return 0x2c34A2Fb1d0b4f55de51E1d0bDEfaDDce6b7cDD6;
        }
        if (block.chainid == 42161) {
            return 0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58;
        }
        if (block.chainid == 8453) {
            return 0x57df6092665eb6058DE53939612413ff4B09114E;
        }
        if (block.chainid == 5000) {
            return 0x57df6092665eb6058DE53939612413ff4B09114E;
        }

        revert("PendleSwap: OKX Chain not supported");
    }

    function _okxScaling(
        bytes calldata rawCallData,
        uint256 actualAmount
    ) internal pure returns (bytes memory scaledCallData) {
        bytes4 selector = bytes4(rawCallData[:4]);
        bytes calldata dataToDecode = rawCallData[4:];

        if (selector == IOKXDexRouter.uniswapV3SwapTo.selector) {
            (uint256 receiver, uint256 amount, uint256 minReturn, uint256[] memory pools) = abi.decode(
                dataToDecode,
                (uint256, uint256, uint256, uint256[])
            );

            minReturn = (minReturn * actualAmount) / amount;
            amount = actualAmount;

            return abi.encodeWithSelector(selector, receiver, amount, minReturn, pools);
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

            batchesAmount = _scaleArray(batchesAmount, actualAmount, baseRequest.fromTokenAmount);
            baseRequest.minReturnAmount = (baseRequest.minReturnAmount * actualAmount) / baseRequest.fromTokenAmount;
            baseRequest.fromTokenAmount = actualAmount;

            return abi.encodeWithSelector(selector, orderId, receiver, baseRequest, batchesAmount, batches, extraData);
        } else if (selector == IOKXDexRouter.unxswapTo.selector) {
            (uint256 srcToken, uint256 amount, uint256 minReturn, address receiver, bytes32[] memory pools) = abi
                .decode(dataToDecode, (uint256, uint256, uint256, address, bytes32[]));

            minReturn = (minReturn * actualAmount) / amount;
            amount = actualAmount;

            return abi.encodeWithSelector(selector, srcToken, amount, minReturn, receiver, pools);
        } else if (selector == IOKXDexRouter.unxswapByOrderId.selector) {
            (uint256 srcToken, uint256 amount, uint256 minReturn, bytes32[] memory pools) = abi.decode(
                dataToDecode,
                (uint256, uint256, uint256, bytes32[])
            );

            minReturn = (minReturn * actualAmount) / amount;
            amount = actualAmount;

            return abi.encodeWithSelector(selector, srcToken, amount, minReturn, pools);
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

            batchesAmount = _scaleArray(batchesAmount, actualAmount, baseRequest.fromTokenAmount);
            baseRequest.minReturnAmount = (baseRequest.minReturnAmount * actualAmount) / baseRequest.fromTokenAmount;
            baseRequest.fromTokenAmount = actualAmount;

            return abi.encodeWithSelector(selector, orderId, baseRequest, batchesAmount, batches, extraData);
        } else {
            revert("PendleSwap: OKX selector not supported");
        }
    }

    function _scaleArray(
        uint256[] memory arr,
        uint256 newAmount,
        uint256 oldAmount
    ) internal pure returns (uint256[] memory scaledArr) {
        scaledArr = new uint256[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            scaledArr[i] = (arr[i] * newAmount) / oldAmount;
        }
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

    function uniswapV3SwapTo(
        uint256 receiver,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata pools
    ) external payable returns (uint256 returnAmount);

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
}
