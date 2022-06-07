// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "./SSTORE2.sol";

abstract contract MiniDeployer {
    function _setCreationCode(bytes memory newCreationCode) internal returns (address pointer) {
        require(newCreationCode.length > 0, "zero length");
        pointer = SSTORE2.write(newCreationCode);
    }

    function _deployWithArgs(address creationCodePointer, bytes memory args)
        internal
        returns (address deployedContract)
    {
        require(creationCodePointer != address(0), "zero pointer");
        bytes memory finalCreationCode = abi.encodePacked(SSTORE2.read(creationCodePointer), args);
        assembly {
            deployedContract := create(0, add(finalCreationCode, 32), mload(finalCreationCode))
        }
        require(deployedContract != address(0), "deployment failed");
    }
}
