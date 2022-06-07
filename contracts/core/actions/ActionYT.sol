// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "./base/ActionSCYAndYTBase.sol";
import "../../interfaces/IPPrincipalToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPActionYT.sol";

contract ActionYT is IPActionYT, ActionSCYAndYTBase {
    using MarketMathCore for MarketState;
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
        uint256 minYtOut,
        ApproxParams memory approx
    ) external returns (uint256) {
        return _swapExactScyForYt(receiver, market, exactScyIn, minYtOut, approx, true);
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
        uint256 maxYtIn,
        ApproxParams memory approx
    ) external returns (uint256) {
        return _swapYtForExactScy(receiver, market, exactScyOut, maxYtIn, approx, true);
    }

    /// @dev docs can be found in the internal function
    function swapExactRawTokenForYt(
        address receiver,
        address market,
        uint256 exactRawTokenIn,
        uint256 minYtOut,
        address[] calldata path,
        ApproxParams memory approx
    ) external returns (uint256) {
        return
            _swapExactRawTokenForYt(
                receiver,
                market,
                exactRawTokenIn,
                minYtOut,
                path,
                approx,
                true
            );
    }

    /// @dev docs can be found in the internal function
    function swapExactYtForRawToken(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minRawTokenOut,
        address[] calldata path
    ) external returns (uint256) {
        return _swapExactYtForRawToken(receiver, market, exactYtIn, minRawTokenOut, path, true);
    }
}
