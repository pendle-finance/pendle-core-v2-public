// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.14;

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
        ApproxParams memory approx
    ) external returns (uint256 netYtOut);

    function swapYtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        ApproxParams memory approx
    ) external returns (uint256 netYtIn);

    function swapExactYtForPt(
        address receiver,
        address market,
        uint256 exactYtIn,
        ApproxParams memory approx
    ) external returns (uint256);

    function swapYtForExactPt(
        address receiver,
        address market,
        uint256 exactPtOut,
        ApproxParams memory approx
    ) external returns (uint256);

    function swapExactPtForYt(
        address receiver,
        address market,
        uint256 exactPtIn,
        ApproxParams memory approx
    ) external returns (uint256);

    function swapPtForExactYt(
        address receiver,
        address market,
        uint256 minYtOut,
        ApproxParams memory approx
    ) external returns (uint256);

    function swapExactRawTokenForYt(
        uint256 exactRawTokenIn,
        address receiver,
        address[] calldata path,
        address market,
        ApproxParams memory approx
    ) external returns (uint256 netYtOut);

    function swapExactYtForRawToken(
        uint256 exactYtIn,
        address receiver,
        address[] calldata path,
        address market,
        uint256 minRawTokenOut
    ) external returns (uint256 netRawTokenOut);
}
