// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "./IPActionCore.sol";
import "./IPActionYT.sol";
import "./IPActionRedeem.sol";

interface IPAllAction is IPActionCore, IPActionYT, IPActionRedeem {}
