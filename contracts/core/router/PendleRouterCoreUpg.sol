// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./base/PendleRouterSCYAndForgeBaseUpg.sol";
import "./base/PendleRouterOTBaseUpg.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPRouterCore.sol";

contract PendleRouterCoreUpg is
    IPRouterCore,
    PendleRouterSCYAndForgeBaseUpg,
    PendleRouterOTBaseUpg
{
    using MarketMathLib for MarketParameters;
    using FixedPoint for uint256;
    using FixedPoint for int256;

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
        address recipient,
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
        return _addLiquidity(recipient, market, scyDesired, otDesired, minLpOut, true);
    }

    /// @dev docs can be found in the internal function
    function removeLiquidity(
        address recipient,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 otOutMin
    ) external returns (uint256, uint256) {
        return _removeLiquidity(recipient, market, lpToRemove, scyOutMin, otOutMin, true);
    }

    /// @dev docs can be found in the internal function
    function swapExactOtForSCY(
        address recipient,
        address market,
        uint256 exactOtIn,
        uint256 minSCYOut
    ) external returns (uint256) {
        return _swapExactOtForSCY(recipient, market, exactOtIn, minSCYOut, true);
    }

    /// @dev docs can be found in the internal function
    function swapOtForExactSCY(
        address recipient,
        address market,
        uint256 maxOtIn,
        uint256 exactSCYOut,
        uint256 netOtInGuessMin,
        uint256 netOtInGuessMax
    ) external returns (uint256) {
        return
            _swapOtForExactSCY(
                recipient,
                market,
                maxOtIn,
                exactSCYOut,
                netOtInGuessMin,
                netOtInGuessMax,
                true
            );
    }

    /// @dev docs can be found in the internal function
    function swapSCYForExactOt(
        address recipient,
        address market,
        uint256 exactOtOut,
        uint256 maxSCYIn
    ) external returns (uint256) {
        return _swapSCYForExactOt(recipient, market, exactOtOut, maxSCYIn, true);
    }

    /// @dev docs can be found in the internal function
    function swapExactSCYForOt(
        address recipient,
        address market,
        uint256 exactSCYIn,
        uint256 minOtOut,
        uint256 netOtOutGuessMin,
        uint256 netOtOutGuessMax
    ) external returns (uint256) {
        return
            _swapExactSCYForOt(
                recipient,
                market,
                exactSCYIn,
                minOtOut,
                netOtOutGuessMin,
                netOtOutGuessMax,
                true
            );
    }

    /// @dev docs can be found in the internal function
    function mintSCYFromRawToken(
        uint256 netRawTokenIn,
        address SCY,
        uint256 minSCYOut,
        address recipient,
        address[] calldata path
    ) external returns (uint256) {
        return _mintSCYFromRawToken(netRawTokenIn, SCY, minSCYOut, recipient, path, true);
    }

    /// @dev docs can be found in the internal function
    function redeemSCYToRawToken(
        address SCY,
        uint256 netSCYIn,
        uint256 minRawTokenOut,
        address recipient,
        address[] memory path
    ) external returns (uint256) {
        return _redeemSCYToRawToken(SCY, netSCYIn, minRawTokenOut, recipient, path, true);
    }

    /// @dev docs can be found in the internal function
    function mintYoFromRawToken(
        uint256 netRawTokenIn,
        address YT,
        uint256 minYoOut,
        address recipient,
        address[] calldata path
    ) external returns (uint256) {
        return _mintYoFromRawToken(netRawTokenIn, YT, minYoOut, recipient, path, true);
    }

    /// @dev docs can be found in the internal function
    function redeemYoToRawToken(
        address YT,
        uint256 netYoIn,
        uint256 minRawTokenOut,
        address recipient,
        address[] memory path
    ) external returns (uint256) {
        return _redeemYoToRawToken(YT, netYoIn, minRawTokenOut, recipient, path, true);
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
