// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract PendleMulticallV1 {
    struct Call {
        address target;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    function aggregate(Call[] calldata calls) public payable virtual {
        uint256 length = calls.length;
        Call calldata call;
        for (uint256 i = 0; i < length; ) {
            call = calls[i];

            (bool success, bytes memory resp) = call.target.call(call.callData);
            if (!success) {
                assembly {
                    revert(add(32, resp), mload(resp))
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function tryAggregate(
        bool requireSuccess,
        uint256 gasLimit,
        Call[] calldata calls
    ) public payable returns (Result[] memory returnData) {
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call calldata call;
        for (uint256 i = 0; i < length; ) {
            call = calls[i];

            (bool success, bytes memory resp) = call.target.call{gas: gasLimit}(calls[i].callData);
            if (!success && requireSuccess) {
                assembly {
                    revert(add(32, resp), mload(resp))
                }
            }

            returnData[i] = Result(success, resp);

            unchecked {
                ++i;
            }
        }
    }
}
