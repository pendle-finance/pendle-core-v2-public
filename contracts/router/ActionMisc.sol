// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../interfaces/IPMarket.sol";
import "../interfaces/IPActionMisc.sol";
import "../core/libraries/Errors.sol";
import "../core/libraries/TokenHelper.sol";

contract ActionMisc is IPActionMisc, TokenHelper {
    using Math for uint256;

    function approveInf(address token, address spender) external {
        _safeApproveInf(token, spender);
    }
}
