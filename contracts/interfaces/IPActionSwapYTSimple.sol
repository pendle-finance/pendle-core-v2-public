// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {TokenInput} from "./IPAllActionTypeV3.sol";
import {IPActionSwapYTV3Events} from "./IPActionSwapYTV3Events.sol";

interface IPActionSwapYTSimple is IPActionSwapYTV3Events {
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
