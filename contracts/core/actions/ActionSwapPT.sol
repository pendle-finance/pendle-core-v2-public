// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./base/ActionBaseSwapPT.sol";
import "../../interfaces/IPActionSwapPT.sol";

contract ActionSwapPT is IPActionSwapPT, ActionBaseSwapPT {
    using MarketMathCore for MarketState;
    using Math for uint256;
    using Math for int256;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter)
        ActionBaseTokenSCY(_kyberSwapRouter) //solhint-disable-next-line no-empty-blocks
    {}

    /// @dev refer to the internal function
    function swapExactPtForScy(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minScyOut
    ) external returns (uint256 netScyOut) {
        netScyOut = _swapExactPtForScy(receiver, market, exactPtIn, minScyOut, true);
        emit SwapPtAndScy(msg.sender, market, receiver, exactPtIn.neg(), netScyOut.Int());
    }

    /// @dev refer to the internal function
    function swapPtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        uint256 maxPtIn,
        ApproxParams calldata guessPtIn
    ) external returns (uint256 netPtIn) {
        netPtIn = _swapPtForExactScy(receiver, market, exactScyOut, maxPtIn, guessPtIn, true);
        emit SwapPtAndScy(msg.sender, market, receiver, netPtIn.neg(), exactScyOut.Int());
    }

    /// @dev refer to the internal function
    function swapScyForExactPt(
        address receiver,
        address market,
        uint256 exactPtOut,
        uint256 maxScyIn
    ) external returns (uint256 netScyIn) {
        netScyIn = _swapScyForExactPt(receiver, market, exactPtOut, maxScyIn, true);
        emit SwapPtAndScy(msg.sender, market, receiver, exactPtOut.Int(), netScyIn.neg());
    }

    /// @dev refer to the internal function
    function swapExactScyForPt(
        address receiver,
        address market,
        uint256 exactScyIn,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut
    ) external returns (uint256 netPtOut) {
        netPtOut = _swapExactScyForPt(receiver, market, exactScyIn, minPtOut, guessPtOut, true);
        emit SwapPtAndScy(msg.sender, market, receiver, netPtOut.Int(), exactScyIn.neg());
    }

    /// @dev refer to the internal function
    function swapExactTokenForPt(
        address receiver,
        address market,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netPtOut) {
        netPtOut = _swapExactTokenForPt(receiver, market, minPtOut, guessPtOut, input);

        emit SwapPtAndToken(
            msg.sender,
            market,
            input.tokenIn,
            receiver,
            netPtOut.Int(),
            input.netTokenIn.neg()
        );
    }

    /// @dev refer to the internal function
    function swapExactPtForToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut) {
        netTokenOut = _swapExactPtForToken(receiver, market, exactPtIn, output, true);

        emit SwapPtAndToken(
            msg.sender,
            market,
            output.tokenOut,
            receiver,
            exactPtIn.neg(),
            netTokenOut.Int()
        );
    }
}
