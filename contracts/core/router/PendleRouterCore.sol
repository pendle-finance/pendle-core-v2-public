// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./base/PendleRouterSCYAndForge.sol";
import "./base/PendleRouterOT.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPRouterRouterCore.sol";

contract PendleRouterCore is IPRouterRouterCore, PendleRouterSCYAndForge, PendleRouterOT {
    using MarketMathLib for MarketParameters;
    using FixedPoint for uint256;
    using FixedPoint for int256;

    constructor(
        address _joeRouter,
        address _joeFactory,
        address _marketFactory
    )
        PendleRouterSCYAndForge(_joeRouter, _joeFactory)
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
        uint256 netOtOutGuessMax
    ) external returns (uint256 netOtOut) {
        address SCY = IPMarket(market).SCY();
        uint256 netSCYUseToBuyOt = _mintSCYFromRawToken(
            exactRawTokenIn,
            SCY,
            1,
            market,
            path,
            true
        );
        netOtOut = _swapExactSCYForOt(
            recipient,
            market,
            netSCYUseToBuyOt,
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
        uint256 minRawTokenOut
    ) external returns (uint256 netRawTokenOut) {
        address SCY = IPMarket(market).SCY();
        _swapExactOtForSCY(SCY, market, exactOtIn, 1, true);
        netRawTokenOut = _redeemSCYToRawToken(SCY, 0, minRawTokenOut, recipient, path, false);
    }
}
