// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../interfaces/IPRouterStatic.sol";
import "../../interfaces/IPMarket.sol";
import "../../libraries/math/MarketMathAux.sol";

contract PendleRouterStaticUpg is IPRouterStatic {
    using MarketMathCore for MarketState;
    using MarketMathAux for MarketState;
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
        MarketState memory state = IPMarket(market).readState(false);
        (, netLpOut, scyUsed, otUsed) = state.addLiquidity(
            scyIndex(market),
            scyDesired,
            otDesired,
            false
        );
    }

    function removeLiquidityStatic(address market, uint256 lpToRemove)
        external
        view
        returns (uint256 netScyOut, uint256 netOtOut)
    {
        MarketState memory state = IPMarket(market).readState(false);
        (netScyOut, netOtOut) = state.removeLiquidity(lpToRemove, false);
    }

    function swapOtForScyStatic(address market, uint256 exactOtIn)
        external
        returns (uint256 netScyOut, uint256 netScyFee)
    {
        MarketState memory state = IPMarket(market).readState(false);
        (netScyOut, netScyFee) = state.swapExactOtForScy(
            scyIndex(market),
            exactOtIn,
            block.timestamp,
            false
        );
    }

    function swapScyForOtStatic(address market, uint256 exactOtOut)
        external
        returns (uint256 netScyIn, uint256 netScyFee)
    {
        MarketState memory state = IPMarket(market).readState(false);
        (netScyIn, netScyFee) = state.swapScyForExactOt(
            scyIndex(market),
            exactOtOut,
            block.timestamp,
            false
        );
    }

    function scyIndex(address market) public returns (SCYIndex index) {
        return SCYIndexLib.newIndex(IPMarket(market).SCY());
    }

    function getOtImpliedYield(address market) external view returns (int256) {
        MarketState memory state = IPMarket(market).readState(false);

        int256 lnImpliedRate = (state.lastImpliedRate).Int();
        return lnImpliedRate.exp();
    }
}
