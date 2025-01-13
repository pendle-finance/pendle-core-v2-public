// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface I1inchCommonType {
    type Address256 is uint256;
}

abstract contract OneInchScaleHelper is I1inchCommonType {
    function _rescaleMinAmount(
        uint256 minAmount,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (uint256) {
        return (minAmount * newAmount) / oldAmount;
    }

    function _oneInchScaling(bytes calldata rawCallData, uint256 actualAmount) internal pure returns (bytes memory) {
        bytes4 selector = bytes4(rawCallData[:4]);
        bytes memory args = rawCallData[4:];

        if (selector == I1inchAggregationRouterV6.unoswapTo.selector) {
            (Address256 to, Address256 token, uint256 amount, uint256 minReturn, Address256 dex) = abi.decode(
                args,
                (Address256, Address256, uint256, uint256, Address256)
            );

            minReturn = (minReturn * actualAmount) / amount;
            amount = actualAmount;
            return abi.encodeWithSelector(selector, to, token, amount, minReturn, dex);
        }

        if (selector == I1inchAggregationRouterV6.unoswapTo2.selector) {
            (Address256 to, Address256 token, uint256 amount, uint256 minReturn, Address256 dex, Address256 dex2) = abi
                .decode(args, (Address256, Address256, uint256, uint256, Address256, Address256));

            minReturn = (minReturn * actualAmount) / amount;
            amount = actualAmount;

            return abi.encodeWithSelector(selector, to, token, amount, minReturn, dex, dex2);
        }

        if (selector == I1inchAggregationRouterV6.unoswapTo3.selector) {
            (
                Address256 to,
                Address256 token,
                uint256 amount,
                uint256 minReturn,
                Address256 dex,
                Address256 dex2,
                Address256 dex3
            ) = abi.decode(args, (Address256, Address256, uint256, uint256, Address256, Address256, Address256));

            minReturn = (minReturn * actualAmount) / amount;
            amount = actualAmount;

            return abi.encodeWithSelector(selector, to, token, amount, minReturn, dex, dex2, dex3);
        }

        if (selector == I1inchAggregationRouterV6.swap.selector) {
            (address executor, I1inchAggregationRouterV6.SwapDescription memory desc, bytes memory data) = abi.decode(
                args,
                (address, I1inchAggregationRouterV6.SwapDescription, bytes)
            );

            desc.minReturnAmount = (desc.minReturnAmount * actualAmount) / desc.amount;
            desc.amount = actualAmount;
            return abi.encodeWithSelector(selector, executor, desc, data);
        }

        revert("1inch: unsupported selector");
    }
}

interface I1inchAggregationRouterV6 is I1inchCommonType {
    struct SwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    // we ignore the non-to version since it's guarantee this contract won't receive tokens

    function unoswapTo(
        Address256 to,
        Address256 token,
        uint256 amount,
        uint256 minReturn,
        Address256 dex
    ) external returns (uint256 returnAmount);

    function unoswapTo2(
        Address256 to,
        Address256 token,
        uint256 amount,
        uint256 minReturn,
        Address256 dex,
        Address256 dex2
    ) external returns (uint256 returnAmount);

    function unoswapTo3(
        Address256 to,
        Address256 token,
        uint256 amount,
        uint256 minReturn,
        Address256 dex,
        Address256 dex2,
        Address256 dex3
    ) external returns (uint256 returnAmount);

    function swap(
        address executor,
        SwapDescription calldata desc,
        bytes calldata data
    ) external payable returns (uint256 returnAmount, uint256 spentAmount);
}
