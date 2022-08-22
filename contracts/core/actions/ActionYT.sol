// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./base/ActionBaseSwapYT.sol";
import "../../interfaces/IPActionSwapYT.sol";

contract ActionSwapYT is IPActionSwapYT, ActionBaseSwapYT {
    using MarketMathCore for MarketState;
    using Math for uint256;
    using Math for int256;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter)
        ActionBaseTokenSCY(_kyberSwapRouter) //solhint-disable-next-line no-empty-blocks
    {}

    /// @dev refer to the internal function
    function swapExactYtForScy(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minScyOut
    ) external returns (uint256 netScyOut) {
        netScyOut = _swapExactYtForScy(receiver, market, exactYtIn, minScyOut, true);
        emit SwapYTAndSCY(receiver, market, exactYtIn.neg(), netScyOut.Int());
    }

    /// @dev refer to the internal function
    function swapScyForExactYt(
        address receiver,
        address market,
        uint256 exactYtOut,
        uint256 maxScyIn
    ) external returns (uint256 netScyIn) {
        netScyIn = _swapScyForExactYt(receiver, market, exactYtOut, maxScyIn);
        emit SwapYTAndSCY(receiver, market, exactYtOut.Int(), netScyIn.neg());
    }

    /// @dev refer to the internal function
    function swapExactScyForYt(
        address receiver,
        address market,
        uint256 exactScyIn,
        uint256 minYtOut,
        ApproxParams memory guessYtOut
    ) external returns (uint256 netYtOut) {
        netYtOut = _swapExactScyForYt(receiver, market, exactScyIn, minYtOut, guessYtOut, true);
        emit SwapYTAndSCY(receiver, market, netYtOut.Int(), exactScyIn.neg());
    }

    /// @dev refer to the internal function
    function swapYtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        uint256 maxYtIn,
        ApproxParams memory guessYtIn
    ) external returns (uint256 netYtIn) {
        netYtIn = _swapYtForExactScy(receiver, market, exactScyOut, maxYtIn, guessYtIn, true);
        emit SwapYTAndSCY(receiver, market, netYtIn.neg(), exactScyOut.Int());
    }

    /// @dev refer to the internal function
    function swapExactTokenForYt(
        address receiver,
        address market,
        uint256 minYtOut,
        ApproxParams memory guessYtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netYtOut) {
        netYtOut = _swapExactTokenForYt(receiver, market, minYtOut, guessYtOut, input);
        emit SwapYTAndToken(
            receiver,
            market,
            input.tokenIn,
            netYtOut.Int(),
            input.netTokenIn.neg()
        );
    }

    /// @dev refer to the internal function
    function swapExactYtForToken(
        address receiver,
        address market,
        uint256 netYtIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut) {
        netTokenOut = _swapExactYtForToken(receiver, market, netYtIn, output, true);
        emit SwapYTAndToken(receiver, market, output.tokenOut, netYtIn.neg(), netTokenOut.Int());
    }
}
