// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.14;

import "./Math.sol";
import "./LogExpMath.sol";
import "../SCYIndex.sol";
import "./MarketMathCore.sol";

// solhint-disable ordering
library MarketMathAux {
    using Math for uint256;
    using Math for int256;

    function addLiquidity(
        MarketState memory market,
        SCYIndex index,
        uint256 scyDesired,
        uint256 ptDesired,
        bool updateState
    )
        internal
        pure
        returns (
            uint256 lpToReserve,
            uint256 lpToAccount,
            uint256 scyUsed,
            uint256 ptUsed
        )
    {
        (
            int256 _lpToReserve,
            int256 _lpToAccount,
            int256 _scyUsed,
            int256 _otUsed
        ) = MarketMathCore.addLiquidityCore(
                market,
                index,
                scyDesired.Int(),
                ptDesired.Int(),
                updateState
            );

        lpToReserve = _lpToReserve.Uint();
        lpToAccount = _lpToAccount.Uint();
        scyUsed = _scyUsed.Uint();
        ptUsed = _otUsed.Uint();
    }

    function removeLiquidity(
        MarketState memory market,
        uint256 lpToRemove,
        bool updateState
    ) internal pure returns (uint256 scyToAccount, uint256 netPtToAccount) {
        (int256 _scyToAccount, int256 _ptToAccount) = MarketMathCore.removeLiquidityCore(
            market,
            lpToRemove.Int(),
            updateState
        );

        scyToAccount = _scyToAccount.Uint();
        netPtToAccount = _ptToAccount.Uint();
    }

    function swapExactPtForScy(
        MarketState memory market,
        SCYIndex index,
        uint256 exactPtToMarket,
        uint256 blockTime
    ) internal pure returns (uint256 netScyToAccount, uint256 netScyToReserve) {
        (int256 _netScyToAccount, int256 _netScyToReserve) = MarketMathCore.executeTradeCore(
            market,
            index,
            exactPtToMarket.neg(),
            blockTime
        );

        netScyToAccount = _netScyToAccount.Uint();
        netScyToReserve = _netScyToReserve.Uint();
    }

    function swapScyForExactPt(
        MarketState memory market,
        SCYIndex index,
        uint256 exactPtToAccount,
        uint256 blockTime
    ) internal pure returns (uint256 netScyToMarket, uint256 netScyToReserve) {
        (int256 _netScyToAccount, int256 _netScyToReserve) = MarketMathCore.executeTradeCore(
            market,
            index,
            exactPtToAccount.Int(),
            blockTime
        );

        netScyToMarket = _netScyToAccount.neg().Uint();
        netScyToReserve = _netScyToReserve.Uint();
    }
}
