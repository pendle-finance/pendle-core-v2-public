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
    )
        PendleRouterLytAndForge(_joeRouter, _joeFactory)
        PendleRouterMarketBase(_marketFactory)
    //solhint-disable-next-line no-empty-blocks
    {

    }

    function swapExactRawTokenForOt(
        uint256 exactRawTokenIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minOtOut,
        uint256 netOtOutGuessMin,
        uint256 netOtOutGuessMax
    ) external returns (uint256 netOtOut) {
        IPMarket _market = IPMarket(market);
        address LYT = _market.LYT();

        uint256 netLytUsedToBuyOT = mintLytFromRawToken(exactRawTokenIn, LYT, 1, market, path);

        MarketParameters memory marketState = _market.readState();
        netOtOut = marketState
            .getSwapExactLytForOt(
                netLytUsedToBuyOT,
                _market.timeToExpiry(),
                netOtOutGuessMin,
                netOtOutGuessMax
            )
            .toUint();

        require(netOtOut >= minOtOut, "insufficient ot");

        _market.swap(recipient, netOtOut.toInt(), abi.encode());
    }

    function swapExactOtForRawToken(
        uint256 exactOtIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minRawTokenOut
    ) external returns (uint256 netRawTokenOut) {
        IPMarket _market = IPMarket(market);
        address OT = _market.OT();
        address LYT = _market.LYT();

        IERC20(OT).transferFrom(msg.sender, market, exactOtIn);

        _market.swap(LYT, exactOtIn.toInt().neg(), abi.encode());
        netRawTokenOut = _redeemLytToRawToken(LYT, minRawTokenOut, recipient, path);
    }

    function swapCallback(
        int256,
        int256,
        bytes calldata //solhint-disable-next-line no-empty-blocks
    ) external {
        // empty body since all tokens has been transferred manually to correct addresses
    }
}
