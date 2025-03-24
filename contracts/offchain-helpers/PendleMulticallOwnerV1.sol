// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../core/libraries/BoringOwnableUpgradeableV2.sol";

contract PendleMulticallOwnerV1 is BoringOwnableUpgradeableV2 {
    error CallThenRevertError(bool success, bytes res);

    struct Call {
        address target;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    constructor(address _owner) {
        __BoringOwnableV2_init(_owner);
    }

    function aggregate(Call[] calldata calls) external payable onlyOwner returns (Result[] memory returnData) {
        uint256 length = calls.length;
        Call calldata call;
        for (uint256 i = 0; i < length; i++) {
            call = calls[i];

            (bool success, bytes memory resp) = call.target.call(call.callData);
            if (!success) {
                assembly {
                    revert(add(32, resp), mload(resp))
                }
            }

            returnData[i] = Result(success, resp);
        }
    }
}
