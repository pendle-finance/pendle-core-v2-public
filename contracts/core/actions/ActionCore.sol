// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

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
    constructor(
        address _joeRouter,
        address _joeFactory,
        address _marketFactory
    )
        ActionSCYAndPYBase(_joeRouter, _joeFactory) //solhint-disable-next-line no-empty-blocks
    {}

    /// @dev docs can be found in the internal function
    function addLiquidity(
        address receiver,
        address market,
        uint256 scyDesired,
        uint256 ptDesired,
        uint256 minLpOut
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return _addLiquidity(receiver, market, scyDesired, ptDesired, minLpOut, true);
    }

    /// @dev docs can be found in the internal function
    function removeLiquidity(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 ptOutMin
    ) external returns (uint256, uint256) {
        return _removeLiquidity(receiver, market, lpToRemove, scyOutMin, ptOutMin, true);
    }

    /// @dev docs can be found in the internal function
    function swapExactPtForScy(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minScyOut
    ) external returns (uint256) {
        return _swapExactPtForScy(receiver, market, exactPtIn, minScyOut, true);
    }

    /// @dev docs can be found in the internal function
    function swapPtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        ApproxParams memory approx
    ) external returns (uint256) {
        return _swapPtForExactScy(receiver, market, exactScyOut, approx, true);
    }

    /// @dev docs can be found in the internal function
    function swapScyForExactPt(
        address receiver,
        address market,
        uint256 exactPtOut,
        uint256 maxScyIn
    ) external returns (uint256) {
        return _swapScyForExactPt(receiver, market, exactPtOut, maxScyIn, true);
    }

    /// @dev docs can be found in the internal function
    function swapExactScyForPt(
        address receiver,
        address market,
        uint256 exactScyIn,
        ApproxParams memory approx
    ) external returns (uint256) {
        return _swapExactScyForPt(receiver, market, exactScyIn, approx, true);
    }

    /// @dev docs can be found in the internal function
    function mintScyFromRawToken(
        uint256 netRawTokenIn,
        address SCY,
        uint256 minScyOut,
        address receiver,
        address[] calldata path
    ) external returns (uint256) {
        return _mintScyFromRawToken(netRawTokenIn, SCY, minScyOut, receiver, path, true);
    }

    /// @dev docs can be found in the internal function
    function redeemScyToRawToken(
        address SCY,
        uint256 netScyIn,
        uint256 minRawTokenOut,
        address receiver,
        address[] memory path
    ) external returns (uint256) {
        return _redeemScyToRawToken(SCY, netScyIn, minRawTokenOut, receiver, path, true);
    }

    /// @dev docs can be found in the internal function
    function mintPyFromRawToken(
        uint256 netRawTokenIn,
        address YT,
        uint256 minPyOut,
        address receiver,
        address[] calldata path
    ) external returns (uint256) {
        return _mintPyFromRawToken(netRawTokenIn, YT, minPyOut, receiver, path, true);
    }

    /// @dev docs can be found in the internal function
    function redeemPyToRawToken(
        address YT,
        uint256 netPyIn,
        uint256 minRawTokenOut,
        address receiver,
        address[] memory path
    ) external returns (uint256) {
        return _redeemPyToRawToken(YT, netPyIn, minRawTokenOut, receiver, path, true);
    }

    /// @dev docs can be found in the internal function
    function swapExactRawTokenForPt(
        uint256 exactRawTokenIn,
        address receiver,
        address[] calldata path,
        address market,
        ApproxParams memory approx
    ) external returns (uint256) {
        return _swapExactRawTokenForPt(exactRawTokenIn, receiver, path, market, approx, true);
    }

    /// @dev docs can be found in the internal function
    function swapExactPtForRawToken(
        uint256 exactPtIn,
        address receiver,
        address[] calldata path,
        address market,
        uint256 minRawTokenOut
    ) external returns (uint256 netRawTokenOut) {
        return _swapExactPtForRawToken(exactPtIn, receiver, path, market, minRawTokenOut, true);
    }

    function redeemDueIncome(
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
                user
            );
        }

        marketRewards = new uint256[][](markets.length);
        for (uint256 i = 0; i < markets.length; ++i) {
            marketRewards[i] = IPMarket(markets[i]).redeemRewards(user);
        }
    }
}
