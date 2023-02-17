// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../interfaces/IPActionMisc.sol";
import "../core/libraries/TokenHelper.sol";

contract ActionMisc is IPActionMisc, TokenHelper {
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

    function batchExec(Call3[] calldata calls) external returns (Result[] memory res) {
        uint256 length = calls.length;

        res = new Result[](length);

        Call3 calldata calli;

        for (uint256 i = 0; i < length; ) {
            calli = calls[i];

            // delegatecall to itself, it turns allowing invoking functions from other actions
            (bool success, bytes memory result) = address(this).delegatecall(calli.callData);

            if (!success && !calli.allowFailure) {
                assembly {
                    // We use Yul's revert() to bubble up errors from the target contract.
                    revert(add(32, result), mload(result))
                }
            }

            res[i].success = success;
            res[i].returnData = result;

            unchecked {
                ++i;
            }
        }
    }
}
