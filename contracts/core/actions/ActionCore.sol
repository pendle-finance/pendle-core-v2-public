// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./base/ActionSCYAndPTBase.sol";
import "./base/ActionSCYAndPYBase.sol";
import "../../interfaces/IPPrincipalToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPActionCore.sol";

contract ActionCore is IPActionCore, ActionSCYAndPTBase {
    using MarketMathCore for MarketState;
    using Math for uint256;
    using Math for int256;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter, address _marketFactory)
        ActionSCYAndPYBase(_kyberSwapRouter) //solhint-disable-next-line no-empty-blocks
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
        require(false, "NOT IMPLEMENTED");
    }

    function addLiquiditySingleScy(
        address receiver,
        address market,
        uint256 netScyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromScy
    ) external returns (uint256 netLpOut) {
        require(false, "NOT IMPLEMENTED");
    }

    function addLiquiditySingleToken(
        address receiver,
        address market,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromScy,
        TokenInput calldata input
    ) external payable returns (uint256 netLpOut) {
        require(false, "NOT IMPLEMENTED");
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
        emit RemoveLiquidityDualIbTokenAndPt(
            msg.sender,
            market,
            receiver,
            lpToRemove,
            netPtOut,
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
        require(false, "NOT IMPLEMENTED");
    }

    function removeLiquiditySingleScy(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 minScyOut
    ) external returns (uint256 netScyOut) {
        require(false, "NOT IMPLEMENTED");
    }

    function removeLiquiditySingleToken(
        address receiver,
        address market,
        uint256 lpToRemove,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut) {
        require(false, "NOT IMPLEMENTED");
    }

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
    function mintScyFromToken(
        address receiver,
        address SCY,
        uint256 minScyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netScyOut) {
        netScyOut = _mintScyFromToken(receiver, SCY, minScyOut, input);

        emit MintScyFromToken(
            msg.sender,
            receiver,
            SCY,
            input.tokenIn,
            input.netTokenIn,
            netScyOut
        );
    }

    /// @dev refer to the internal function
    function redeemScyToToken(
        address receiver,
        address SCY,
        uint256 netScyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut) {
        netTokenOut = _redeemScyToToken(receiver, SCY, netScyIn, output, true);
        emit RedeemScyToToken(msg.sender, receiver, SCY, netScyIn, output.tokenOut, netTokenOut);
    }

    /// @dev refer to the internal function
    function mintPyFromToken(
        address receiver,
        address YT,
        uint256 minPyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netPyOut) {
        netPyOut = _mintPyFromToken(receiver, YT, minPyOut, input);
        emit MintPyFromToken(msg.sender, receiver, YT, input.tokenIn, input.netTokenIn, netPyOut);
    }

    /// @dev refer to the internal function
    function redeemPyToToken(
        address receiver,
        address YT,
        uint256 netPyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut) {
        netTokenOut = _redeemPyToToken(receiver, YT, netPyIn, output, true);
        emit RedeemPyToToken(msg.sender, receiver, YT, netPyIn, output.tokenOut, netTokenOut);
    }

    function mintPyFromScy(
        address receiver,
        address YT,
        uint256 netScyIn,
        uint256 minPyOut
    ) external returns (uint256 netPyOut) {
        netPyOut = _mintPyFromScy(receiver, YT, netScyIn, minPyOut, true);
        emit MintPyFromScy(msg.sender, receiver, YT, netScyIn, netPyOut);
    }

    function redeemPyToScy(
        address receiver,
        address YT,
        uint256 netPyIn,
        uint256 minScyOut
    ) external returns (uint256 netScyOut) {
        netScyOut = _redeemPyToScy(receiver, YT, netPyIn, minScyOut, true);
        emit RedeemPyToScy(msg.sender, receiver, YT, netPyIn, netScyOut);
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

    function redeemDueInterestAndRewards(
        address user,
        address[] calldata scys,
        address[] calldata yts,
        address[] calldata markets
    )
        external
        returns (
            uint256[][] memory scyRewards,
            uint256[] memory ytInterests,
            uint256[][] memory ytRewards,
            uint256[][] memory marketRewards
        )
    {
        scyRewards = new uint256[][](scys.length);
        for (uint256 i = 0; i < scys.length; ++i) {
            scyRewards[i] = ISuperComposableYield(scys[i]).claimRewards(user);
        }

        ytInterests = new uint256[](yts.length);
        ytRewards = new uint256[][](yts.length);
        for (uint256 i = 0; i < yts.length; ++i) {
            (ytInterests[i], ytRewards[i]) = IPYieldToken(yts[i]).redeemDueInterestAndRewards(
                user,
                true,
                true
            );
        }

        marketRewards = new uint256[][](markets.length);
        for (uint256 i = 0; i < markets.length; ++i) {
            marketRewards[i] = IPMarket(markets[i]).redeemRewards(user);
        }
    }
}
