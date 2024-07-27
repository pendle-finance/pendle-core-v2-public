// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendleGTokenSY.sol";

contract PendleGUSDCSY is PendleGTokenSY {
    address public constant gUSDC = 0xd3443ee1e91aF28e5FB858Fbd0D72A63bA8046E0;

    constructor() PendleGTokenSY("SY gUSDC", "SY-gUSDC", gUSDC) {}
}
