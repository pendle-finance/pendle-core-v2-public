// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./FixedPoint.sol";
import "./LogExpMath.sol";
import "../SCYIndex.sol";
import "./MarketMathCore.sol";

// solhint-disable ordering
library MarketMathUint {
    using FixedPoint for uint256;
    using FixedPoint for int256;

    function addLiquidity(
        MarketAllParams memory market,
        SCYIndex index,
        uint256 scyDesired,
        uint256 otDesired
    )
        internal
        pure
        returns (
            uint256 lpToReserve,
            uint256 lpToAccount,
            uint256 scyUsed,
            uint256 otUsed
        )
    {
        (
            int256 _lpToReserve,
            int256 _lpToAccount,
            int256 _scyUsed,
            int256 _otUsed
        ) = MarketMathCore.addLiquidityCore(market, index, scyDesired.Int(), otDesired.Int());

        lpToReserve = _lpToReserve.Uint();
        lpToAccount = _lpToAccount.Uint();
        scyUsed = _scyUsed.Uint();
        otUsed = _otUsed.Uint();
    }

    function removeLiquidity(MarketAllParams memory market, uint256 lpToRemove)
        internal
        pure
        returns (uint256 scyToAccount, uint256 netOtToAccount)
    {
        (int256 _scyToAccount, int256 _otToAccount) = MarketMathCore.removeLiquidityCore(
            market,
            lpToRemove.Int()
        );

        scyToAccount = _scyToAccount.Uint();
        netOtToAccount = _otToAccount.Uint();
    }

    function swapExactOtForScy(
        MarketAllParams memory market,
        SCYIndex index,
        uint256 exactOtToMarket,
        uint256 blockTime
    ) internal pure returns (uint256 netScyToAccount, uint256 netScyToReserve) {
        (int256 _netScyToAccount, int256 _netScyToReserve) = MarketMathCore.executeTradeCore(
            market,
            index,
            exactOtToMarket.neg(),
            blockTime
        );

        netScyToAccount = _netScyToAccount.Uint();
        netScyToReserve = _netScyToReserve.Uint();
    }

    function swapScyForExactOt(
        MarketAllParams memory market,
        SCYIndex index,
        uint256 exactOtToAccount,
        uint256 blockTime
    ) internal pure returns (uint256 netScyToMarket, uint256 netScyToReserve) {
        (int256 _netScyToAccount, int256 _netScyToReserve) = MarketMathCore.executeTradeCore(
            market,
            index,
            exactOtToAccount.Int(),
            blockTime
        );

        netScyToMarket = _netScyToAccount.neg().Uint();
        netScyToReserve = _netScyToReserve.Uint();
    }
}
