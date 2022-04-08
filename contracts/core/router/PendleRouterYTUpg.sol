// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./base/PendleRouterSCYAndForgeBaseUpg.sol";
import "./base/PendleRouterYTBaseUpg.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";

contract PendleRouterYTUpg is PendleRouterSCYAndForgeBaseUpg, PendleRouterYTBaseUpg {
    using MarketMathLib for MarketParameters;
    using FixedPoint for uint256;
    using FixedPoint for int256;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(
        address _joeRouter,
        address _joeFactory,
        address _marketFactory
    )
        PendleRouterSCYAndForgeBaseUpg(_joeRouter, _joeFactory)
        PendleRouterYTBaseUpg(_marketFactory)
    //solhint-disable-next-line no-empty-blocks
    {

    }

    function swapExactYtForSCY(
        address recipient,
        address market,
        uint256 exactYtIn,
        uint256 minSCYOut
    ) external returns (uint256) {
        return _swapExactYtForSCY(recipient, market, exactYtIn, minSCYOut, true);
    }

    function swapSCYForExactYt(
        address recipient,
        address market,
        uint256 exactYtOut,
        uint256 maxSCYIn
    ) external returns (uint256) {
        return _swapSCYForExactYt(recipient, market, exactYtOut, maxSCYIn);
    }

    function swapExactSCYForYt(
        address recipient,
        address market,
        uint256 exactSCYIn,
        uint256 minYtOut,
        uint256 netYtOutGuessMin,
        uint256 netYtOutGuessMax
    ) external returns (uint256) {
        return
            _swapExactSCYForYt(
                recipient,
                market,
                exactSCYIn,
                minYtOut,
                netYtOutGuessMin,
                netYtOutGuessMax,
                true
            );
    }

    /**
     * @dev netYtOutGuessMin & Max can be used in the same way as RawTokenOT
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
     * @dev inner working of this function:
     - mintSCYFromRawToken is invoked, except the YT contract will receive all the outcome SCY
     - market.swap is called, which will transfer SCY to the YT contract, and callback is invoked
     - callback will do call YT's mintYO, which will mint OT to the market & YT to the recipient
     */
    function swapExactRawTokenForYt(
        uint256 exactRawTokenIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minYtOut,
        uint256 netYtOutGuessMin,
        uint256 netYtOutGuessMax
    ) external returns (uint256 netYtOut) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 netSCYUsedToBuyYT = _mintSCYFromRawToken(
            exactRawTokenIn,
            address(SCY),
            1,
            address(YT),
            path,
            true
        );

        netYtOut = _swapExactSCYForYt(
            recipient,
            market,
            netSCYUsedToBuyYT,
            minYtOut,
            netYtOutGuessMin,
            netYtOutGuessMax,
            false
        );
    }

    /**
     * @notice swap YT -> SCY -> baseToken -> rawToken
     * @notice the algorithm to swap will guarantee to swap all the YT available
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
     * @dev inner working of this function:
     - YT is transferred to the YT contract
     - market.swap is called, which will transfer OT directly to the YT contract, and callback is invoked
     - callback will do call YT's redeemYO, which will redeem the outcome SCY to this router, then
        all SCY owed to the market will be paid, the rest is used to feed redeemSCYToRawToken
     */
    function swapExactYtForRawToken(
        uint256 exactYtIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minRawTokenOut
    ) external returns (uint256 netRawTokenOut) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        uint256 netSCYOut = _swapExactYtForSCY(address(SCY), market, exactYtIn, 1, true);

        netRawTokenOut = _redeemSCYToRawToken(
            address(SCY),
            netSCYOut,
            minRawTokenOut,
            recipient,
            path,
            false
        );
    }
}
