// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPRouterOT {
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
    ) external returns (uint256 netSCYOut, uint256 netOtOut);

    function swapExactOtForSCY(
        address recipient,
        address market,
        uint256 exactOtIn,
        uint256 minSCYOut
    ) external returns (uint256 netSCYOut);

    function swapOtForExactSCY(
        address recipient,
        address market,
        uint256 maxOtIn,
        uint256 exactSCYOut,
        uint256 netOtInGuessMin,
        uint256 netOtInGuessMax
    ) external returns (uint256 netOtIn);

    function swapSCYForExactOt(
        address recipient,
        address market,
        uint256 exactOtOut,
        uint256 maxSCYIn
    ) external returns (uint256 netSCYIn);

    function swapExactSCYForOt(
        address recipient,
        address market,
        uint256 exactSCYIn,
        uint256 minOtOut,
        uint256 netOtOutGuessMin,
        uint256 netOtOutGuessMax
    ) external returns (uint256 netOtOut);
}
