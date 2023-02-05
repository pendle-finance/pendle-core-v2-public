// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../interfaces/IPMarket.sol";
import "../interfaces/IPActionMisc.sol";
import "../core/libraries/Errors.sol";
import "../core/libraries/TokenHelper.sol";

contract ActionMisc is IPActionMisc, TokenHelper {
    using Math for uint256;

    function approveInf(MultiApproval[] calldata arr) external {
        for (uint256 i = 0; i < arr.length; ) {
            MultiApproval calldata ele = arr[i];
            for (uint256 j = 0; j < ele.tokens.length; ) {
                _safeApproveInf(ele.tokens[j], ele.spender);
                unchecked {
                    j++;
                }
            }
            unchecked {
                i++;
            }
        }
    }
}
