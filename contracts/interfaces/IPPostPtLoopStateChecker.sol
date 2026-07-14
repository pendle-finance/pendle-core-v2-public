// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {IPLoopPositionBox} from "./IPLoopPositionBox.sol";

interface IPPostPtLoopStateChecker {
    function check(IPLoopPositionBox box, bytes calldata data) external;
}
