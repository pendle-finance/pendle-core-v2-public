// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./PendleRouterLytAndForge.sol";
import "./PendleRouterOT.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";

contract PendleRouterRawTokenOT is PendleRouterLytAndForge, PendleRouterOT {
    using MarketMathLib for MarketParameters;
    using FixedPoint for uint256;
    using FixedPoint for int256;

    constructor(
        address _joeRouter,
        address _joeFactory,
        address _marketFactory
    )
        PendleRouterLytAndForge(_joeRouter, _joeFactory)
        PendleRouterOT(_marketFactory)
    //solhint-disable-next-line no-empty-blocks
    {

    }

    /**
    * @dev netOtOutGuessMin & netOtOutGuessMax the minimum & maximum possible guess for the netOtOut
    the correct otOut must lie between this range, else the function will revert.
    * @dev the smaller the range, the fewer iterations it will take (hence less gas). The expected way
    to create the guess is to run this function with min = 0, max = type(uint256.max) to trigger the widest
    guess range. After getting the result, min = result * (100-slippage) & max = result * (100+slippage)
    * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
    */
    function swapExactRawTokenForOt(
        uint256 exactRawTokenIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minOtOut,
        uint256 netOtOutGuessMin,
        uint256 netOtOutGuessMax,
        bool doPull
    ) external returns (uint256 netOtOut) {
        address LYT = IPMarket(market).LYT();
        uint256 netLytUseToBuyOt = mintLytFromRawToken(
            exactRawTokenIn,
            LYT,
            1,
            market,
            path,
            doPull
        );
        netOtOut = swapExactLytForOt(
            recipient,
            market,
            netLytUseToBuyOt,
            minOtOut,
            netOtOutGuessMin,
            netOtOutGuessMax,
            false
        );
    }

    /**
     * @notice sell all Ot for RawToken
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
     */
    function swapExactOtForRawToken(
        uint256 exactOtIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minRawTokenOut,
        bool doPull
    ) external returns (uint256 netRawTokenOut) {
        address LYT = IPMarket(market).LYT();
        swapExactOtForLyt(LYT, market, exactOtIn, 1, doPull);
        netRawTokenOut = redeemLytToRawToken(LYT, 0, minRawTokenOut, recipient, path, false);
    }
}
