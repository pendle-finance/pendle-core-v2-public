// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../libraries/math/MarketApproxLib.sol";

interface IPActionYT {
    function swapExactYtForScy(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minScyOut
    ) external returns (uint256 netScyOut);

    function swapScyForExactYt(
        address receiver,
        address market,
        uint256 exactYtOut,
        uint256 maxScyIn
    ) external returns (uint256 netScyIn);

    function swapExactScyForYt(
        address receiver,
        address market,
        uint256 exactScyIn,
        uint256 minYtOut,
        ApproxParams memory guessYtOut
    ) external returns (uint256 netYtOut);

    function swapYtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        uint256 maxYtIn,
        ApproxParams memory guessYtIn
    ) external returns (uint256 netYtIn);

    function swapExactRawTokenForYt(
        address receiver,
        address market,
        uint256 exactRawTokenIn,
        uint256 minYtOut,
        address[] calldata path,
        ApproxParams memory guessYtOut
    ) external returns (uint256 netYtOut);

    function swapExactYtForRawToken(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minRawTokenOut,
        address[] calldata path
    ) external returns (uint256 netRawTokenOut);
}
