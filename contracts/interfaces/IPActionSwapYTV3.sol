// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../router/math/MarketApproxLib.sol";
import "./IPAllActionTypeV3.sol";
import {IPActionSwapYTV3Events} from "./IPActionSwapYTV3Events.sol";

/*
 *******************************************************************************************************************
 *******************************************************************************************************************
 * NOTICE *
 * Refer to https://docs.pendle.finance/Developers/Contracts/PendleRouter for more information on
 * TokenInput, TokenOutput, ApproxParams, LimitOrderData
 * It's recommended to use Pendle's Hosted SDK to generate the params
 *******************************************************************************************************************
 *******************************************************************************************************************
 */

interface IPActionSwapYTV3 is IPActionSwapYTV3Events {
    function swapExactTokenForYt(
        address receiver,
        address market,
        uint256 minYtOut,
        ApproxParams calldata guessYtOut,
        TokenInput calldata input,
        LimitOrderData calldata limit
    ) external payable returns (uint256 netYtOut, uint256 netSyFee, uint256 netSyInterm);

    function swapExactSyForYt(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minYtOut,
        ApproxParams calldata guessYtOut,
        LimitOrderData calldata limit
    ) external returns (uint256 netYtOut, uint256 netSyFee);

    function swapExactYtForToken(
        address receiver,
        address market,
        uint256 exactYtIn,
        TokenOutput calldata output,
        LimitOrderData calldata limit
    ) external returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm);

    function swapExactYtForSy(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minSyOut,
        LimitOrderData calldata limit
    ) external returns (uint256 netSyOut, uint256 netSyFee);

    function swapExactPtForYt(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minYtOut,
        ApproxParams calldata guessTotalPtToSwap
    ) external returns (uint256 netYtOut, uint256 netSyFee);

    function swapExactYtForPt(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minPtOut,
        ApproxParams calldata guessTotalPtFromSwap
    ) external returns (uint256 netPtOut, uint256 netSyFee);
}
