// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../libraries/math/MarketApproxLib.sol";

interface IPActionCore {
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
        );

    function removeLiquidity(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 ptOutMin
    ) external returns (uint256, uint256);

    function swapExactPtForScy(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minScyOut
    ) external returns (uint256);

    function swapPtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        ApproxParams memory approx
    ) external returns (uint256);

    function swapScyForExactPt(
        address receiver,
        address market,
        uint256 exactPtOut,
        uint256 maxScyIn
    ) external returns (uint256);

    function swapExactScyForPt(
        address receiver,
        address market,
        uint256 exactScyIn,
        ApproxParams memory approx
    ) external returns (uint256);

    function mintScyFromRawToken(
        uint256 netRawTokenIn,
        address SCY,
        uint256 minScyOut,
        address receiver,
        address[] calldata path
    ) external returns (uint256);

    function redeemScyToRawToken(
        address SCY,
        uint256 netScyIn,
        uint256 minRawTokenOut,
        address receiver,
        address[] memory path
    ) external returns (uint256);

    function mintPyFromRawToken(
        uint256 netRawTokenIn,
        address YT,
        uint256 minPyOut,
        address receiver,
        address[] calldata path
    ) external returns (uint256);

    function redeemPyToRawToken(
        address YT,
        uint256 netPyIn,
        uint256 minRawTokenOut,
        address receiver,
        address[] memory path
    ) external returns (uint256);

    function swapExactRawTokenForPt(
        uint256 exactRawTokenIn,
        address receiver,
        address[] calldata path,
        address market,
        ApproxParams memory approx
    ) external returns (uint256 netPtOut);

    function swapExactPtForRawToken(
        uint256 exactPtIn,
        address receiver,
        address[] calldata path,
        address market,
        uint256 minRawTokenOut
    ) external returns (uint256 netRawTokenOut);
}
