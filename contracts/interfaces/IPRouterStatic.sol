// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../libraries/math/MarketMathCore.sol";

interface IPRouterStatic {
    function addLiquidityStatic(
        address market,
        uint256 scyDesired,
        uint256 ptDesired
    )
        external
        returns (
            uint256 netLpOut,
            uint256 scyUsed,
            uint256 ptUsed
        );

    function removeLiquidityStatic(address market, uint256 lpToRemove)
        external
        view
        returns (uint256 netScyOut, uint256 netPtOut);

    function swapPtForScyStatic(address market, uint256 exactPtIn)
        external
        returns (uint256 netScyOut, uint256 netScyFee);

    function swapScyForPtStatic(address market, uint256 exactPtOut)
        external
        returns (uint256 netScyIn, uint256 netScyFee);

    function scyIndex(address market) external returns (SCYIndex index);

    function getPtImpliedYield(address market) external view returns (int256);

    function getPendleTokenType(address token)
        external
        view
        returns (
            bool isPT,
            bool isYT,
            bool isMarket
        );
}
