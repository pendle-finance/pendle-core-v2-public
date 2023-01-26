// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IAggregationExecutor.sol";

interface IMetaAggregationRouter {
    struct SwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address[] srcReceivers;
        uint256[] srcAmounts;
        address dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
        bytes permit;
    }

    function swap(
        IAggregationExecutor caller,
        SwapDescription calldata desc,
        bytes calldata executorData,
        bytes calldata clientData
    ) external payable returns (uint256, uint256);

    function swapSimpleMode(
        IAggregationExecutor caller,
        SwapDescription calldata desc,
        bytes calldata executorData,
        bytes calldata clientData
    ) external returns (uint256, uint256);
}
