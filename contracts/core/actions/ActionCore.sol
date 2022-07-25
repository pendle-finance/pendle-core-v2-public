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

    /// @dev since this contract will be proxied, it must not contains non-immutable variabless
    constructor(address _joeFactory, address _marketFactory)
        ActionSCYAndPYBase(_joeFactory) //solhint-disable-next-line no-empty-blocks
    {}

    /// @dev refer to the internal function
    function addLiquidity(
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
        (netLpOut, scyUsed, ptUsed) = _addLiquidity(
            receiver,
            market,
            scyDesired,
            ptDesired,
            minLpOut,
            true
        );
        emit AddLiquidity(msg.sender, market, receiver, scyUsed, ptUsed, netLpOut);
    }

    function addLiquiditySinglePt(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 minLpOut,
        ApproxParams memory guessPtSwapToScy
    ) external returns (uint256 netLpOut) {
        require(false, "NOT IMPLEMENTED");
    }

    function addLiquiditySingleScy(
        address receiver,
        address market,
        uint256 netScyIn,
        uint256 minLpOut,
        ApproxParams memory guessPtReceivedFromScy
    ) external returns (uint256 netLpOut) {
        require(false, "NOT IMPLEMENTED");
    }

    function addLiquiditySingleRawToken(
        address receiver,
        address market,
        uint256 netRawTokenIn,
        uint256 minLpOut,
        address[] calldata path,
        ApproxParams memory guessPtReceivedFromScy
    ) external returns (uint256 netLpOut) {
        require(false, "NOT IMPLEMENTED");
    }

    /// @dev refer to the internal function
    function removeLiquidity(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 ptOutMin
    ) external returns (uint256 netScyOut, uint256 netPtOut) {
        (netScyOut, netPtOut) = _removeLiquidity(
            receiver,
            market,
            lpToRemove,
            scyOutMin,
            ptOutMin,
            true
        );
        emit RemoveLiquidity(msg.sender, market, receiver, lpToRemove, netPtOut, netScyOut);
    }

    function removeLiquiditySinglePt(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 minPtOut,
        ApproxParams memory guessPtOut
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

    function removeLiquiditySingleRawToken(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 minRawTokenOut,
        address[] memory path
    ) external returns (uint256 netRawTokenOut) {
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
        ApproxParams memory guessPtIn
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
        ApproxParams memory guessPtOut
    ) external returns (uint256 netPtOut) {
        netPtOut = _swapExactScyForPt(receiver, market, exactScyIn, minPtOut, guessPtOut, true);
        emit SwapPtAndScy(msg.sender, market, receiver, netPtOut.Int(), exactScyIn.neg());
    }

    /// @dev refer to the internal function
    function mintScyFromRawToken(
        address receiver,
        address SCY,
        uint256 netRawTokenIn,
        uint256 minScyOut,
        address[] calldata path
    ) external returns (uint256 netScyOut) {
        return _mintScyFromRawToken(receiver, SCY, netRawTokenIn, minScyOut, path, true);
    }

    /// @dev refer to the internal function
    function redeemScyToRawToken(
        address receiver,
        address SCY,
        uint256 netScyIn,
        uint256 minRawTokenOut,
        address[] memory path
    ) external returns (uint256 netRawTokenOut) {
        netRawTokenOut = _redeemScyToRawToken(receiver, SCY, netScyIn, minRawTokenOut, path, true);
        emit RedeemScyToRawToken(
            msg.sender,
            receiver,
            SCY,
            netScyIn,
            path[path.length - 1],
            netRawTokenOut
        );
    }

    /// @dev refer to the internal function
    function mintPyFromRawToken(
        address receiver,
        address YT,
        uint256 netRawTokenIn,
        uint256 minPyOut,
        address[] calldata path
    ) external returns (uint256 netPyOut) {
        netPyOut = _mintPyFromRawToken(receiver, YT, netRawTokenIn, minPyOut, path, true);
        emit MintPyFromRawToken(msg.sender, receiver, YT, path[0], netRawTokenIn, netPyOut);
    }

    /// @dev refer to the internal function
    function redeemPyToRawToken(
        address receiver,
        address YT,
        uint256 netPyIn,
        uint256 minRawTokenOut,
        address[] memory path
    ) external returns (uint256 netRawTokenOut) {
        netRawTokenOut = _redeemPyToRawToken(receiver, YT, netPyIn, minRawTokenOut, path, true);
        emit RedeemPyToRawToken(
            msg.sender,
            receiver,
            YT,
            netPyIn,
            path[path.length - 1],
            netRawTokenOut
        );
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
    function swapExactRawTokenForPt(
        address receiver,
        address market,
        uint256 exactRawTokenIn,
        uint256 minPtOut,
        address[] calldata path,
        ApproxParams memory guessPtOut
    ) external returns (uint256 netPtOut) {
        netPtOut = _swapExactRawTokenForPt(
            receiver,
            market,
            exactRawTokenIn,
            minPtOut,
            path,
            guessPtOut,
            true
        );

        emit SwapPtAndRawToken(
            msg.sender,
            market,
            path[0],
            receiver,
            netPtOut.Int(),
            exactRawTokenIn.neg()
        );
    }

    /// @dev refer to the internal function
    function swapExactPtForRawToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minRawTokenOut,
        address[] calldata path
    ) external returns (uint256 netRawTokenOut) {
        netRawTokenOut = _swapExactPtForRawToken(
            receiver,
            market,
            exactPtIn,
            minRawTokenOut,
            path,
            true
        );
        emit SwapPtAndRawToken(
            msg.sender,
            market,
            path[path.length - 1],
            receiver,
            exactPtIn.neg(),
            netRawTokenOut.Int()
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
