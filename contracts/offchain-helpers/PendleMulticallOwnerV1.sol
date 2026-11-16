// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../core/libraries/BoringOwnableUpgradeableV2.sol";

contract PendleMulticallOwnerV1 is BoringOwnableUpgradeableV2 {
    struct Call {
        address target;
        uint256 value;
        bytes callData;
    }

    constructor(address _owner) initializer {
        __BoringOwnableV2_init(_owner);
    }

    function aggregate(Call[] calldata calls) external payable onlyOwner returns (bytes[] memory rtnData) {
        uint256 length = calls.length;
        rtnData = new bytes[](length);

        Call calldata call;
        for (uint256 i = 0; i < length; i++) {
            call = calls[i];

            (bool success, bytes memory resp) = call.target.call{value: call.value}(call.callData);
            if (!success) {
                assembly {
                    revert(add(32, resp), mload(resp))
                }
            }

            rtnData[i] = resp;
        }
    }

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
