// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./base/ActionSCYAndYTBase.sol";
import "../../interfaces/IPPrincipalToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPActionYT.sol";
import "../../libraries/math/MarketMathAux.sol";

contract ActionYT is IPActionYT, ActionSCYAndYTBase {
    using MarketMathCore for MarketState;
    using MarketMathAux for MarketState;
    using Math for uint256;
    using Math for int256;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _joeRouter, address _joeFactory)
        ActionSCYAndPYBase(_joeRouter, _joeFactory)
    //solhint-disable-next-line no-empty-blocks
    {

    }

    /**
     * @dev Take in a fixed amount of YT and returns receiver a corresponding amount of SCY
     * @dev inner working step
       - Transfer exactYtIn amount of YT to YT
       - market.swapScyToExactPt is called, the receiver of PT is YT
       - YT.redeemPY is called, burning exactYtIn YT & PT to SCY
       - Return the owed Scy for contract, the rest is transferred to user
     */
    function swapExactYtForScy(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minScyOut
    ) external returns (uint256) {
        return _swapExactYtForScy(receiver, market, exactYtIn, minScyOut, true);
    }

    /**
     * @dev Take in a corresponding amount of SCY & return receiver a fixed amount of YT
     * @dev inner working step
       - Input SCY is transferred to YT address
       - swap.swapExactPtForScy is called the receiver is YT
       - YT.mintPY is called, granting router exactYtOut YT & PT
       - The owed PT is paid by setting the PT receiver is market, YT receiver is $receiver
     */
    function swapScyForExactYt(
        address receiver,
        address market,
        uint256 exactYtOut,
        uint256 maxScyIn
    ) external returns (uint256) {
        return _swapScyForExactYt(receiver, market, exactYtOut, maxScyIn);
    }

    /**
     * @dev Take in a fixed a mount of SCY and return receiver the corresponding amount of YT
     * @dev can refer to the doc of swapExactRawTokenForYt
     * @param approx params to approx. Guess params will be the min, max & offchain guess for netYtOut
     */
    function swapExactScyForYt(
        address receiver,
        address market,
        uint256 exactScyIn,
        ApproxParams memory approx
    ) external returns (uint256 netYtOut) {
        return _swapExactScyForYt(receiver, market, exactScyIn, approx, true);
    }

    /**
     * @dev take in a correesponding amount of YT & return an exactScyOut amount of SCY
     * @dev can refer to the doc of swapExactYtForRawToken
     * @param approx params to approx. Guess params will be the min, max & offchain guess for netYtIn
     */
    function swapYtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        ApproxParams memory approx
    ) external returns (uint256 netYtIn) {
        return _swapYtForExactScy(receiver, market, exactScyOut, approx, true);
    }

    /**
     * @dev netYtOutGuessMin & Max can be used in the same way as RawTokenPT
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
     * @dev inner working of this function:
     - mintScyFromRawToken is invoked, except the YT contract will receive all the outcome SCY
     - market.swapExactPtToScy is called, which will transfer SCY to the YT contract, and callback is invoked
     - callback will do call YT.mintPT, which will mint PT to the market & YT to the receiver
     * @param approx params to approx. Guess params will be the min, max & offchain guess for netYtOut
     */
    function swapExactRawTokenForYt(
        uint256 exactRawTokenIn,
        address receiver,
        address[] calldata path,
        address market,
        ApproxParams memory approx
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

        netYtOut = _swapExactScyForYt(receiver, market, netScyUsedToBuyYT, approx, false);
    }

    /**
     * @notice swap YT -> SCY -> baseToken -> rawToken
     * @notice the algorithm to swap will guarantee to swap all the YT available
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
     * @dev inner working of this function:
     - YT is transferred to the YT contract
     - market.swapScyForExactPt is called, which will transfer PT directly to the YT contract, and callback is invoked
     - callback will do call YT.redeemPY, which will redeem the outcome SCY to this router, then
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
