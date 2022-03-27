// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./PendleRouterLytAndForge.sol";
import "./PendleRouterOT.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";

contract PendleRouterRawTokenOT is
    PendleRouterLytAndForge,
    PendleRouterMarketBase,
    IPMarketSwapCallback
{
    using MarketMathLib for MarketParameters;
    using FixedPoint for uint256;
    using FixedPoint for int256;

    constructor(
        address _joeRouter,
        address _joeFactory,
        address _marketFactory
    ) PendleRouterLytAndForge(_joeRouter, _joeFactory) PendleRouterMarketBase(_marketFactory) {}

    function swapExactRawTokenForOT(
        uint256 amountRawTokenIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minAmountOTOut,
        uint256 amountOTOutGuess,
        uint256 guessRange
    ) external returns (uint256 amountOTOut) {
        IPMarket _market = IPMarket(market);
        address LYT = _market.LYT();

        uint256 amountLYTUsedToBuyOT = mintLytFromRawToken(amountRawTokenIn, LYT, 1, market, path);

        MarketParameters memory marketState = _market.readState();
        amountOTOut = marketState
            .getOtGivenLytAmount(
                amountLYTUsedToBuyOT.toInt().neg(),
                _market.timeToExpiry(),
                amountOTOutGuess.toInt(),
                guessRange
            )
            .toUint();

        require(amountOTOut >= minAmountOTOut, "insufficient ot");
        _market.swap(recipient, amountOTOut.toInt(), abi.encode());
    }

    function swapExactOTForRawToken(
        uint256 amountOTIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minRawTokenOut
    ) external returns (uint256 netRawTokenOut) {
        IPMarket _market = IPMarket(market);
        address OT = _market.OT();
        address LYT = _market.LYT();

        IERC20(OT).transferFrom(msg.sender, market, amountOTIn);

        _market.swap(LYT, amountOTIn.toInt().neg(), abi.encode());
        netRawTokenOut = _redeemLytToRawToken(LYT, minRawTokenOut, recipient, path);
    }

    function swapCallback(
        int256,
        int256,
        bytes calldata
    ) external {
        // empty body since all tokens has been transferred manually to correct addresses
    }
}
