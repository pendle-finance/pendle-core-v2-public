// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../libraries/math/MarketMathCore.sol";

interface IPRouterStatic {
    function addLiquidityStatic(
        address market,
        uint256 scyDesired,
        uint256 otDesired
    )
        external
        returns (
            uint256 netLpOut,
            uint256 scyUsed,
            uint256 otUsed
        );

    function removeLiquidityStatic(address market, uint256 lpToRemove)
        external
        view
        returns (uint256 netScyOut, uint256 netOtOut);

    function swapOtForScyStatic(address market, uint256 exactOtIn)
        external
        returns (uint256 netScyOut, uint256 netScyFee);

    function swapScyForOtStatic(address market, uint256 exactOtOut)
        external
        returns (uint256 netScyIn, uint256 netScyFee);

    function scyIndex(address market) external returns (SCYIndex index);

    function getOtImpliedYield(address market) external view returns (int256);
}
