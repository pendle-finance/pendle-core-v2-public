// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../interfaces/IPRouterStatic.sol";
import "../../interfaces/IPMarket.sol";
import "../../libraries/math/MarketMathUint.sol";

contract PendleRouterStaticUpg is IPRouterStatic {
    using MarketMathCore for MarketAllParams;
    using MarketMathUint for MarketAllParams;
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using LogExpMath for int256;

    /// @dev since this contract will be proxied, it must not contains non-immutable variabless
    constructor(
        address _joeRouter,
        address _joeFactory,
        address _marketFactory //solhint-disable-next-line no-empty-blocks
    ) {}

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
        )
    {
        MarketAllParams memory state = IPMarket(market).readState();
        (, netLpOut, scyUsed, otUsed) = state.addLiquidity(
            scyIndex(market),
            scyDesired,
            otDesired
        );
    }

    function removeLiquidityStatic(address market, uint256 lpToRemove)
        external
        view
        returns (uint256 netScyOut, uint256 netOtOut)
    {
        MarketAllParams memory state = IPMarket(market).readState();
        (netScyOut, netOtOut) = state.removeLiquidity(lpToRemove);
    }

    function swapOtForScyStatic(address market, uint256 exactOtIn)
        external
        returns (uint256 netScyOut, uint256 netScyFee)
    {
        MarketAllParams memory state = IPMarket(market).readState();
        (netScyOut, netScyFee) = state.swapExactOtForScy(
            scyIndex(market),
            exactOtIn,
            block.timestamp
        );
    }

    function swapScyForOtStatic(address market, uint256 exactOtOut)
        external
        returns (uint256 netScyIn, uint256 netScyFee)
    {
        MarketAllParams memory state = IPMarket(market).readState();
        (netScyIn, netScyFee) = state.swapScyForExactOt(
            scyIndex(market),
            exactOtOut,
            block.timestamp
        );
    }

    function scyIndex(address market) public returns (SCYIndex index) {
        return SCYIndexLib.newIndex(IPMarket(market).SCY());
    }

    function getOtImpliedYield(address market) external view returns (int256) {
        MarketAllParams memory state = IPMarket(market).readState();

        int256 lnImpliedRate = (state.lastImpliedRate).Int();
        return lnImpliedRate.exp();
    }
}
