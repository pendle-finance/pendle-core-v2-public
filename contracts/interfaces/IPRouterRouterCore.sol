// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IPRouterSCYAndForge.sol";
import "./IPRouterOT.sol";

interface IPRouterRouterCore is IPRouterSCYAndForge, IPRouterOT {
    function swapExactRawTokenForOt(
        uint256 exactRawTokenIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minOtOut,
        uint256 netOtOutGuessMin,
        uint256 netOtOutGuessMax
    ) external returns (uint256 netOtOut);

    function swapExactOtForRawToken(
        uint256 exactOtIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minRawTokenOut
    ) external returns (uint256 netRawTokenOut);
}
