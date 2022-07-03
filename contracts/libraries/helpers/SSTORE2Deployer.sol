// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "../solmate/SSTORE2.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

/// @dev save creation code of a contract onchain, and load it when necessary
library SSTORE2Deployer {
    function setCreationCode(bytes memory newCreationCode) internal returns (address pointer) {
        require(newCreationCode.length > 0, "zero length");
        pointer = SSTORE2.write(newCreationCode);
    }

    function create2(
        address creationCodePointer,
        bytes32 salt,
        bytes memory args
    ) internal returns (address) {
        return create2(SSTORE2.read(creationCodePointer), salt, args);
    }

    // call create2 directly by the provided creationCode
    function create2(
        bytes memory creationCode,
        bytes32 salt,
        bytes memory args
    ) internal returns (address) {
        bytes memory finalCreationCode = abi.encodePacked(creationCode, args);
        return Create2.deploy(0, salt, finalCreationCode);
    }
}
