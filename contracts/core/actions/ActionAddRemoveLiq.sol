// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./base/ActionBaseAddRemoveLiq.sol";
import "../../interfaces/IPActionAddRemoveLiq.sol";

contract ActionAddRemoveLiq is ActionBaseAddRemoveLiq, IPActionAddRemoveLiq {
    using MarketMathCore for MarketState;
    using Math for uint256;
    using Math for int256;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter)
        ActionBaseAddRemoveLiq(_kyberSwapRouter) //solhint-disable-next-line no-empty-blocks
    {}

    /// @dev refer to the internal function
    function addLiquidityDualScyAndPt(
        address receiver,
        address market,
        uint256 scyDesired,
        uint256 ptDesired,
        uint256 minLpOut
    )
        external
        returns (
            uint256 netLpOut,
            uint256 scyUsed,
            uint256 ptUsed
        )
    {
        (netLpOut, scyUsed, ptUsed) = _addLiquidityDualScyAndPt(
            receiver,
            market,
            scyDesired,
            ptDesired,
            minLpOut,
            true
        );
        emit AddLiquidityDualScyAndPt(msg.sender, market, receiver, scyUsed, ptUsed, netLpOut);
    }

    /// @dev refer to the internal function
    function addLiquidityDualTokenAndPt(
        address receiver,
        address market,
        address tokenIn,
        uint256 tokenDesired,
        uint256 ptDesired,
        uint256 minLpOut
    )
        external
        payable
        returns (
            uint256 netLpOut,
            uint256 tokenUsed,
            uint256 ptUsed
        )
    {
        (netLpOut, tokenUsed, ptUsed) = _addLiquidityDualTokenAndPt(
            receiver,
            market,
            tokenIn,
            tokenDesired,
            ptDesired,
            minLpOut
        );
        emit AddLiquidityDualTokenAndPt(
            msg.sender,
            market,
            receiver,
            tokenIn,
            tokenDesired,
            ptUsed,
            netLpOut
        );
    }

    function addLiquiditySinglePt(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtSwapToScy
    ) external returns (uint256 netLpOut) {
        netLpOut = _addLiquiditySinglePt(
            receiver,
            market,
            netPtIn,
            minLpOut,
            guessPtSwapToScy,
            true
        );
        emit AddLiquiditySinglePt(msg.sender, market, receiver, netPtIn, netLpOut);
    }

    function addLiquiditySingleScy(
        address receiver,
        address market,
        uint256 netScyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromScy
    ) external returns (uint256 netLpOut) {
        netLpOut = _addLiquiditySingleScy(
            receiver,
            market,
            netScyIn,
            minLpOut,
            guessPtReceivedFromScy,
            true
        );
        emit AddLiquiditySingleScy(msg.sender, market, receiver, netScyIn, netLpOut);
    }

    function addLiquiditySingleToken(
        address receiver,
        address market,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromScy,
        TokenInput calldata input
    ) external payable returns (uint256 netLpOut) {
        netLpOut = _addLiquiditySingleToken(
            receiver,
            market,
            minLpOut,
            guessPtReceivedFromScy,
            input
        );
        emit AddLiquiditySingleToken(
            msg.sender,
            market,
            input.tokenIn,
            receiver,
            input.netTokenIn,
            netLpOut
        );
    }

    /// @dev refer to the internal function
    function removeLiquidityDualScyAndPt(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 ptOutMin
    ) external returns (uint256 netScyOut, uint256 netPtOut) {
        (netScyOut, netPtOut) = _removeLiquidityDualScyAndPt(
            receiver,
            market,
            lpToRemove,
            scyOutMin,
            ptOutMin
        );
        emit RemoveLiquidityDualScyAndPt(
            msg.sender,
            market,
            receiver,
            lpToRemove,
            netPtOut,
            netScyOut
        );
    }

    /// @dev refer to the internal function
    function removeLiquidityDualTokenAndPt(
        address receiver,
        address market,
        uint256 lpToRemove,
        address tokenOut,
        uint256 tokenOutMin,
        uint256 ptOutMin
    ) external returns (uint256 netTokenOut, uint256 netPtOut) {
        (netTokenOut, netPtOut) = _removeLiquidityDualTokenAndPt(
            receiver,
            market,
            lpToRemove,
            tokenOut,
            tokenOutMin,
            ptOutMin
        );
        emit RemoveLiquidityDualTokenAndPt(
            msg.sender,
            market,
            receiver,
            lpToRemove,
            netPtOut,
            tokenOut,
            netTokenOut
        );
    }

    function removeLiquiditySinglePt(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut
    ) external returns (uint256 netPtOut) {
        netPtOut = _removeLiquiditySinglePt(receiver, market, lpToRemove, minPtOut, guessPtOut);
        emit RemoveLiquiditySinglePt(msg.sender, market, receiver, lpToRemove, netPtOut);
    }

    function removeLiquiditySingleScy(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 minScyOut
    ) external returns (uint256 netScyOut) {
        netScyOut = _removeLiquiditySingleScy(receiver, market, lpToRemove, minScyOut);
        emit RemoveLiquiditySingleScy(msg.sender, market, receiver, lpToRemove, netScyOut);
    }

    function removeLiquiditySingleToken(
        address receiver,
        address market,
        uint256 lpToRemove,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut) {
        netTokenOut = _removeLiquiditySingleToken(receiver, market, lpToRemove, output);
        emit RemoveLiquiditySingleToken(
            msg.sender,
            market,
            output.tokenOut,
            receiver,
            lpToRemove,
            netTokenOut
        );
    }
}
