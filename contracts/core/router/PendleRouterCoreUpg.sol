// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./base/PendleRouterSCYAndForgeBaseUpg.sol";
import "./base/PendleRouterOTBaseUpg.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPRouterCore.sol";
import "../../libraries/math/MarketMathAux.sol";

contract PendleRouterCoreUpg is
    IPRouterCore,
    PendleRouterSCYAndForgeBaseUpg,
    PendleRouterOTBaseUpg
{
    using MarketMathCore for MarketState;
    using MarketMathAux for MarketState;
    using Math for uint256;
    using Math for int256;

    /// @dev since this contract will be proxied, it must not contains non-immutable variabless
    constructor(
        address _joeRouter,
        address _joeFactory,
        address _marketFactory
    )
        PendleRouterSCYAndForgeBaseUpg(_joeRouter, _joeFactory)
        PendleRouterOTBaseUpg()
    //solhint-disable-next-line no-empty-blocks
    {

    }

    /// @dev docs can be found in the internal function
    function addLiquidity(
        address receiver,
        address market,
        uint256 scyDesired,
        uint256 otDesired,
        uint256 minLpOut
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return _addLiquidity(receiver, market, scyDesired, otDesired, minLpOut, true);
    }

    /// @dev docs can be found in the internal function
    function removeLiquidity(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 otOutMin
    ) external returns (uint256, uint256) {
        return _removeLiquidity(receiver, market, lpToRemove, scyOutMin, otOutMin, true);
    }

    /// @dev docs can be found in the internal function
    function swapExactOtForScy(
        address receiver,
        address market,
        uint256 exactOtIn,
        uint256 minScyOut
    ) external returns (uint256) {
        return _swapExactOtForScy(receiver, market, exactOtIn, minScyOut, true);
    }

    /// @dev docs can be found in the internal function
    function swapOtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        uint256 otInGuessMin,
        uint256 otInGuessMax,
        uint256 maxIteration,
        uint256 eps
    ) external returns (uint256) {
        return
            _swapOtForExactScy(
                receiver,
                market,
                exactScyOut,
                ApproxParams({
                    guessMin: otInGuessMin,
                    guessMax: otInGuessMax,
                    eps: eps,
                    maxIteration: maxIteration
                }),
                true
            );
    }

    /// @dev docs can be found in the internal function
    function swapScyForExactOt(
        address receiver,
        address market,
        uint256 exactOtOut,
        uint256 maxScyIn
    ) external returns (uint256) {
        return _swapScyForExactOt(receiver, market, exactOtOut, maxScyIn, true);
    }

    /// @dev docs can be found in the internal function
    function swapExactScyForOt(
        address receiver,
        address market,
        uint256 exactScyIn,
        uint256 otOutguessMin,
        uint256 otOutguessMax,
        uint256 maxIteration,
        uint256 eps
    ) external returns (uint256) {
        return
            _swapExactScyForOt(
                receiver,
                market,
                exactScyIn,
                ApproxParams({
                    guessMin: otOutguessMin,
                    guessMax: otOutguessMax,
                    eps: eps,
                    maxIteration: maxIteration
                }),
                true
            );
    }

    /// @dev docs can be found in the internal function
    function mintScyFromRawToken(
        uint256 netRawTokenIn,
        address SCY,
        uint256 minScyOut,
        address receiver,
        address[] calldata path
    ) external returns (uint256) {
        return _mintScyFromRawToken(netRawTokenIn, SCY, minScyOut, receiver, path, true);
    }

    /// @dev docs can be found in the internal function
    function redeemScyToRawToken(
        address SCY,
        uint256 netScyIn,
        uint256 minRawTokenOut,
        address receiver,
        address[] memory path
    ) external returns (uint256) {
        return _redeemScyToRawToken(SCY, netScyIn, minRawTokenOut, receiver, path, true);
    }

    /// @dev docs can be found in the internal function
    function mintYoFromRawToken(
        uint256 netRawTokenIn,
        address YT,
        uint256 minYoOut,
        address receiver,
        address[] calldata path
    ) external returns (uint256) {
        return _mintYoFromRawToken(netRawTokenIn, YT, minYoOut, receiver, path, true);
    }

    /// @dev docs can be found in the internal function
    function redeemYoToRawToken(
        address YT,
        uint256 netYoIn,
        uint256 minRawTokenOut,
        address receiver,
        address[] memory path
    ) external returns (uint256) {
        return _redeemYoToRawToken(YT, netYoIn, minRawTokenOut, receiver, path, true);
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
        address receiver,
        address[] calldata path,
        address market,
        uint256 otOutguessMin,
        uint256 otOutguessMax,
        uint256 maxIteration,
        uint256 eps
    ) external returns (uint256 netOtOut) {
        address SCY = IPMarket(market).SCY();
        uint256 netScyUseToBuyOt = _mintScyFromRawToken(
            exactRawTokenIn,
            SCY,
            1,
            market,
            path,
            true
        );
        netOtOut = _swapExactScyForOt(
            receiver,
            market,
            netScyUseToBuyOt,
            ApproxParams({
                guessMin: otOutguessMin,
                guessMax: otOutguessMax,
                eps: eps,
                maxIteration: maxIteration
            }),
            false
        );
    }

    /**
     * @notice sell all Ot for RawToken
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
     */
    function swapExactOtForRawToken(
        uint256 exactOtIn,
        address receiver,
        address[] calldata path,
        address market,
        uint256 minRawTokenOut
    ) external returns (uint256 netRawTokenOut) {
        address SCY = IPMarket(market).SCY();
        _swapExactOtForScy(SCY, market, exactOtIn, 1, true);
        netRawTokenOut = _redeemScyToRawToken(SCY, 0, minRawTokenOut, receiver, path, false);
    }
}
