// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "./base/ActionSCYAndYTBase.sol";
import "../../interfaces/IPPrincipalToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPActionYT.sol";

contract ActionYT is IPActionYT, ActionSCYAndYTBase {
    using MarketMathCore for MarketState;
    using Math for uint256;
    using Math for int256;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _joeRouter, address _joeFactory)
        ActionSCYAndPYBase(_joeRouter, _joeFactory)
    //solhint-disable-next-line no-empty-blocks
    {

    }

    /// @dev refer to the internal function
    function swapExactYtForScy(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minScyOut
    ) external returns (uint256 netScyOut) {
        return _swapExactYtForScy(receiver, market, exactYtIn, minScyOut, true);
    }

    /// @dev refer to the internal function
    function swapScyForExactYt(
        address receiver,
        address market,
        uint256 exactYtOut,
        uint256 maxScyIn
    ) external returns (uint256 netScyIn) {
        return _swapScyForExactYt(receiver, market, exactYtOut, maxScyIn);
    }

    /// @dev refer to the internal function
    function swapExactScyForYt(
        address receiver,
        address market,
        uint256 exactScyIn,
        uint256 minYtOut,
        ApproxParams memory guessYtOut
    ) external returns (uint256 netYtOut) {
        return _swapExactScyForYt(receiver, market, exactScyIn, minYtOut, guessYtOut, true);
    }

    /// @dev refer to the internal function
    function swapYtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        uint256 maxYtIn,
        ApproxParams memory guessYtIn
    ) external returns (uint256 netYtIn) {
        return _swapYtForExactScy(receiver, market, exactScyOut, maxYtIn, guessYtIn, true);
    }

    /// @dev refer to the internal function
    function swapExactRawTokenForYt(
        address receiver,
        address market,
        uint256 exactRawTokenIn,
        uint256 minYtOut,
        address[] calldata path,
        ApproxParams memory guessYtOut
    ) external returns (uint256 netYtOut) {
        return
            _swapExactRawTokenForYt(
                receiver,
                market,
                exactRawTokenIn,
                minYtOut,
                path,
                guessYtOut,
                true
            );
    }

    /// @dev refer to the internal function
    function swapExactYtForRawToken(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minRawTokenOut,
        address[] calldata path
    ) external returns (uint256 netRawTokenOut) {
        return _swapExactYtForRawToken(receiver, market, exactYtIn, minRawTokenOut, path, true);
    }
}
