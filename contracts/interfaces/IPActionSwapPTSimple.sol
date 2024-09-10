// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {TokenInput} from "./IPAllActionTypeV3.sol";
import {IPActionSwapPTV3Events} from "./IPActionSwapPTV3Events.sol";

interface IPActionSwapPTSimple is IPActionSwapPTV3Events {
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
}
