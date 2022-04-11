// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPRouterCore {
    function addLiquidity(
        address recipient,
        address market,
        uint256 scyDesired,
        uint256 otDesired,
        uint256 minLpOut
    )
        external
        returns (
            uint256 netLpOut,
            uint256 scyUsed,
            uint256 otUsed
        );

    function removeLiquidity(
        address recipient,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 otOutMin
    ) external returns (uint256 netScyOut, uint256 netOtOut);

    function swapExactOtForScy(
        address recipient,
        address market,
        uint256 exactOtIn,
        uint256 minScyOut
    ) external returns (uint256 netScyOut);

    function swapOtForExactScy(
        address recipient,
        address market,
        uint256 maxOtIn,
        uint256 exactScyOut,
        uint256 netOtInGuessMin,
        uint256 netOtInGuessMax
    ) external returns (uint256 netOtIn);

    function swapScyForExactOt(
        address recipient,
        address market,
        uint256 exactOtOut,
        uint256 maxScyIn
    ) external returns (uint256 netScyIn);

    function swapExactScyForOt(
        address recipient,
        address market,
        uint256 exactScyIn,
        uint256 minOtOut,
        uint256 netOtOutGuessMin,
        uint256 netOtOutGuessMax
    ) external returns (uint256 netOtOut);

    function mintScyFromRawToken(
        uint256 netRawTokenIn,
        address SCY,
        uint256 minScyOut,
        address recipient,
        address[] calldata path
    ) external returns (uint256 netScyOut);

    function redeemScyToRawToken(
        address SCY,
        uint256 netScyIn,
        uint256 minRawTokenOut,
        address recipient,
        address[] memory path
    ) external returns (uint256 netRawTokenOut);

    function mintYoFromRawToken(
        uint256 netRawTokenIn,
        address YT,
        uint256 minYoOut,
        address recipient,
        address[] calldata path
    ) external returns (uint256 netYoOut);

    function redeemYoToRawToken(
        address YT,
        uint256 netYoIn,
        uint256 minRawTokenOut,
        address recipient,
        address[] memory path
    ) external returns (uint256 netRawTokenOut);

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
