// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {TokenInput} from "./IPAllActionTypeV3.sol";
import {IPAllEventsV3} from "./IPAllEventsV3.sol";
import "./IPAllActionTypeV3.sol";

/// @notice This interface contains a set of functions that similar to
/// functions defined in
/// `./IPActionAddRemoveLiqV3.sol`, `./IPActionSwapPTV3.sol`, `./IPActionSwapYTV3.sol`.
/// These functions have stripped down parameters compared to their counterparts.
/// All functions in this interface will not interact with Pendle Limit Order,
/// and will do on-chain approximation.
///
/// @dev The onchain approximation algorithm are defined in `/contracts/router/math/MarketApproxLibOnchain.sol`
interface IPActionSimple is IPAllEventsV3 {
    function addLiquiditySinglePtSimple(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 minLpOut
    ) external returns (uint256 netLpOut, uint256 netSyFee);

    function addLiquiditySingleTokenSimple(
        address receiver,
        address market,
        uint256 minLpOut,
        TokenInput calldata input
    ) external payable returns (uint256 netLpOut, uint256 netSyFee, uint256 netSyInterm);

    function addLiquiditySingleSySimple(
        address receiver,
        address market,
        uint256 netSyIn,
        uint256 minLpOut
    ) external returns (uint256 netLpOut, uint256 netSyFee);

    function removeLiquiditySinglePtSimple(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minPtOut
    ) external returns (uint256 netPtOut, uint256 netSyFee);

    function swapExactTokenForPtSimple(
        address receiver,
        address market,
        uint256 minPtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm);

    function swapExactSyForPtSimple(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minPtOut
    ) external returns (uint256 netPtOut, uint256 netSyFee);

    function swapExactTokenForYtSimple(
        address receiver,
        address market,
        uint256 minYtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netYtOut, uint256 netSyFee, uint256 netSyInterm);

    function swapExactSyForYtSimple(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minYtOut
    ) external returns (uint256 netYtOut, uint256 netSyFee);
}
