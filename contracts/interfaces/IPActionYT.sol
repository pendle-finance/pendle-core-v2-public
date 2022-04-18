// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

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
        uint256 netYtOutGuessMin,
        uint256 netYtOutGuessMax,
        uint256 maxIteration,
        uint256 eps
    ) external returns (uint256 netYtOut);

    function swapYtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        uint256 netYtInGuessMin,
        uint256 netYtInGuessMax,
        uint256 maxIteration,
        uint256 eps
    ) external returns (uint256 netYtIn);

    function swapExactRawTokenForYt(
        uint256 exactRawTokenIn,
        address receiver,
        address[] calldata path,
        address market,
        uint256 netYtOutGuessMin,
        uint256 netYtOutGuessMax,
        uint256 maxIteration,
        uint256 eps
    ) external returns (uint256 netYtOut);

    function swapExactYtForRawToken(
        uint256 exactYtIn,
        address receiver,
        address[] calldata path,
        address market,
        uint256 minRawTokenOut
    ) external returns (uint256 netRawTokenOut);
}
