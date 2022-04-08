// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IPMarketSwapCallback.sol";

interface IPRouterYT is IPMarketSwapCallback {
    function swapExactYtForSCY(
        address recipient,
        address market,
        uint256 exactYtIn,
        uint256 minSCYOut
    ) external returns (uint256 netSCYOut);

    function swapSCYForExactYt(
        address recipient,
        address market,
        uint256 exactYtOut,
        uint256 maxSCYIn
    ) external returns (uint256 netSCYIn);

    function swapExactSCYForYt(
        address recipient,
        address market,
        uint256 exactSCYIn,
        uint256 minYtOut,
        uint256 netYtOutGuessMin,
        uint256 netYtOutGuessMax
    ) external returns (uint256 netYtOut);

    function swapExactRawTokenForYt(
        uint256 exactRawTokenIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minYtOut,
        uint256 netYtOutGuessMin,
        uint256 netYtOutGuessMax
    ) external returns (uint256 netYtOut);

    function swapExactYtForRawToken(
        uint256 exactYtIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minRawTokenOut
    ) external returns (uint256 netRawTokenOut);
}
