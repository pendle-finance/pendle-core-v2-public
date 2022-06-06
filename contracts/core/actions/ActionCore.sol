// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.14;

import "./base/ActionSCYAndPTBase.sol";
import "./base/ActionSCYAndPYBase.sol";
import "../../interfaces/IPPrincipalToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPActionCore.sol";
import "../../libraries/math/MarketMathAux.sol";

contract ActionCore is IPActionCore, ActionSCYAndPTBase, ActionSCYAndPYBase {
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
        ActionSCYAndPYBase(_joeRouter, _joeFactory) //solhint-disable-next-line no-empty-blocks
    {}

    /// @dev docs can be found in the internal function
    function addLiquidity(
        address receiver,
        address market,
        uint256 scyDesired,
        uint256 ptDesired,
        uint256 minLpOut
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return _addLiquidity(receiver, market, scyDesired, ptDesired, minLpOut, true);
    }

    function addLiquiditySinglePT(
        address receiver,
        address market,
        uint256 ptIn,
        uint256 minLpOut,
        ApproxParams memory approx
    ) external returns (uint256) {
        return _addLiquiditySinglePT(receiver, market, ptIn, minLpOut, approx, true);
    }

    function addLiquiditySingleSCY(
        address receiver,
        address market,
        uint256 scyIn,
        uint256 minLpOut,
        ApproxParams memory approx
    ) external returns (uint256) {
        return _addLiquiditySingleSCY(receiver, market, scyIn, minLpOut, approx, true);
    }

    /// @dev docs can be found in the internal function
    function removeLiquidity(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 ptOutMin
    ) external returns (uint256, uint256) {
        return _removeLiquidity(receiver, market, lpToRemove, scyOutMin, ptOutMin, true);
    }

    function removeLiquiditySinglePT(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 minPtOut,
        ApproxParams memory approx
    ) external returns (uint256) {
        return _removeLiquiditySinglePT(receiver, market, lpToRemove, minPtOut, approx, true);
    }

    function removeLiquiditySingleSCY(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 minScyOut
    ) external returns (uint256) {
        return _removeLiquiditySingleSCY(receiver, market, lpToRemove, minScyOut, true);
    }

    /// @dev docs can be found in the internal function
    function swapExactPtForScy(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minScyOut
    ) external returns (uint256) {
        return _swapExactPtForScy(receiver, market, exactPtIn, minScyOut, true);
    }

    /// @dev docs can be found in the internal function
    function swapPtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        ApproxParams memory approx
    ) external returns (uint256) {
        return _swapPtForExactScy(receiver, market, exactScyOut, approx, true);
    }

    /// @dev docs can be found in the internal function
    function swapScyForExactPt(
        address receiver,
        address market,
        uint256 exactPtOut,
        uint256 maxScyIn
    ) external returns (uint256) {
        return _swapScyForExactPt(receiver, market, exactPtOut, maxScyIn, true);
    }

    /// @dev docs can be found in the internal function
    function swapExactScyForPt(
        address receiver,
        address market,
        uint256 exactScyIn,
        ApproxParams memory approx
    ) external returns (uint256) {
        return _swapExactScyForPt(receiver, market, exactScyIn, approx, true);
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
    function mintPyFromRawToken(
        uint256 netRawTokenIn,
        address YT,
        uint256 minPyOut,
        address receiver,
        address[] calldata path
    ) external returns (uint256) {
        return _mintPyFromRawToken(netRawTokenIn, YT, minPyOut, receiver, path, true);
    }

    /// @dev docs can be found in the internal function
    function redeemPyToRawToken(
        address YT,
        uint256 netPyIn,
        uint256 minRawTokenOut,
        address receiver,
        address[] memory path
    ) external returns (uint256) {
        return _redeemPyToRawToken(YT, netPyIn, minRawTokenOut, receiver, path, true);
    }

    /**
    * @dev netPtOutGuessMin & netPtOutGuessMax the minimum & maximum possible guess for the netPtOut
    the correct ptOut must lie between this range, else the function will revert.
    * @dev the smaller the range, the fewer iterations it will take (hence less gas). The expected way
    to create the guess is to run this function with min = 0, max = type(uint256.max) to trigger the widest
    guess range. After getting the result, min = result * (1-eps) & max = result * (1+eps)
    * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
    * @param approx params to approx. Guess params will be the min, max & offchain guess for netPtOut
    */
    function swapExactRawTokenForPt(
        uint256 exactRawTokenIn,
        address receiver,
        address[] calldata path,
        address market,
        ApproxParams memory approx
    ) external returns (uint256 netPtOut) {
        address SCY = IPMarket(market).SCY();
        uint256 netScyUseToBuyPt = _mintScyFromRawToken(
            exactRawTokenIn,
            SCY,
            1,
            market,
            path,
            true
        );
        netPtOut = _swapExactScyForPt(receiver, market, netScyUseToBuyPt, approx, false);
    }

    /**
     * @notice sell all Pt for RawToken
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
     */
    function swapExactPtForRawToken(
        uint256 exactPtIn,
        address receiver,
        address[] calldata path,
        address market,
        uint256 minRawTokenOut
    ) external returns (uint256 netRawTokenOut) {
        address SCY = IPMarket(market).SCY();
        _swapExactPtForScy(SCY, market, exactPtIn, 1, true);
        netRawTokenOut = _redeemScyToRawToken(SCY, 0, minRawTokenOut, receiver, path, false);
    }
}
