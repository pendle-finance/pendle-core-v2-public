// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../router/base/MarketApproxLib.sol";
import "./IPAllActionTypeV3.sol";
import {IPActionAddRemoveLiqV3Events} from "./IPActionAddRemoveLiqV3Events.sol";

interface IPActionAddRemoveLiqSimple is IPActionAddRemoveLiqV3Events {
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

    function removeLiquiditySingleTokenSimple(
        address receiver,
        address market,
        uint256 netLpToRemove,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm);

    function removeLiquiditySingleSySimple(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minSyOut
    ) external returns (uint256 netSyOut, uint256 netSyFee);
}
