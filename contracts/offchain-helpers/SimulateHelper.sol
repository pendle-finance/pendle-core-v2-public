// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../core/libraries/Errors.sol";

contract SimulateHelper {
    address private immutable original;

    constructor() {
        original = address(this);
    }

    function multicallRevert(
        uint256 gasLimit,
        address[] calldata targets,
        bytes[] calldata callDatas
    ) public payable virtual returns (bytes[] memory res, uint256[] memory gasUsed) {
        require(targets.length == callDatas.length, "length mismatch");

        uint256 length = callDatas.length;
        res = new bytes[](length);
        gasUsed = new uint256[](length);
        for (uint256 i = 0; i < length; ) {
            uint256 gasBefore = gasleft();
            (, res[i]) = original.delegatecall{gas: gasLimit}(
                abi.encodeWithSignature("simulate(address,bytes)", targets[i], callDatas[i])
            );
            gasUsed[i] = gasBefore - gasleft();

            unchecked {
                ++i;
            }
        }
    }

    function simulate(address target, bytes calldata data) external payable {
        (bool success, bytes memory result) = target.delegatecall(data);
        revert Errors.SimulationResults(success, result);
    }
}
