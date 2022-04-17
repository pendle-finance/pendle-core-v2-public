// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./base/PendleRouterSCYAndForgeBaseUpg.sol";
import "./base/PendleRouterYTBaseUpg.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPRouterYT.sol";
import "../../libraries/math/MarketMathAux.sol";

contract PendleRouterYTUpg is IPRouterYT, PendleRouterSCYAndForgeBaseUpg, PendleRouterYTBaseUpg {
    using MarketMathCore for MarketState;
    using MarketMathAux for MarketState;
    using Math for uint256;
    using Math for int256;

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

    function swapExactYtForScy(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minScyOut
    ) external returns (uint256) {
        return _swapExactYtForScy(receiver, market, exactYtIn, minScyOut, true);
    }

    function swapScyForExactYt(
        address receiver,
        address market,
        uint256 exactYtOut,
        uint256 maxScyIn
    ) external returns (uint256) {
        return _swapScyForExactYt(receiver, market, exactYtOut, maxScyIn);
    }

    function swapExactScyForYt(
        address receiver,
        address market,
        uint256 exactScyIn,
        uint256 minYtOut,
        uint256 netYtOutGuessMin,
        uint256 netYtOutGuessMax
    ) external returns (uint256) {
        return
            _swapExactScyForYt(
                receiver,
                market,
                exactScyIn,
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
     - mintScyFromRawToken is invoked, except the YT contract will receive all the outcome SCY
     - market.swap is called, which will transfer SCY to the YT contract, and callback is invoked
     - callback will do call YT's mintYO, which will mint OT to the market & YT to the receiver
     */
    function swapExactRawTokenForYt(
        uint256 exactRawTokenIn,
        address receiver,
        address[] calldata path,
        address market,
        uint256 minYtOut,
        uint256 netYtOutGuessMin,
        uint256 netYtOutGuessMax
    ) external returns (uint256 netYtOut) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 netScyUsedToBuyYT = _mintScyFromRawToken(
            exactRawTokenIn,
            address(SCY),
            1,
            address(YT),
            path,
            true
        );

        netYtOut = _swapExactScyForYt(
            receiver,
            market,
            netScyUsedToBuyYT,
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
        all SCY owed to the market will be paid, the rest is used to feed redeemScyToRawToken
     */
    function swapExactYtForRawToken(
        uint256 exactYtIn,
        address receiver,
        address[] calldata path,
        address market,
        uint256 minRawTokenOut
    ) external returns (uint256 netRawTokenOut) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        uint256 netScyOut = _swapExactYtForScy(address(SCY), market, exactYtIn, 1, true);

        netRawTokenOut = _redeemScyToRawToken(
            address(SCY),
            netScyOut,
            minRawTokenOut,
            receiver,
            path,
            false
        );
    }
}
