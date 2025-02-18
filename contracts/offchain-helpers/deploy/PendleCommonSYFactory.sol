// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../core/libraries/BoringOwnableUpgradeable.sol";
import "../../core/libraries/BaseSplitCodeFactory.sol";
import "../../interfaces/IOwnable.sol";

contract PendleCommonSYFactory is BoringOwnableUpgradeable {
    error InvalidCreationCode(bytes32 id, CreationCode code);

    error InvalidSYId(bytes32 id);

    struct CreationCode {
        address creationCodeContractA;
        uint256 creationCodeSizeA;
        address creationCodeContractB;
        uint256 creationCodeSizeB;
    }

    event SetSYCreationCode(bytes32 id, CreationCode code);

    event DeployedSY(bytes32 id, bytes constructorParams, address SY);

    mapping(bytes32 => CreationCode) public creationCodes;

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function setSYCreationCode(bytes32 id, CreationCode memory code) external onlyOwner {
        if (
            code.creationCodeContractA == address(0) ||
            code.creationCodeContractB == address(0) ||
            code.creationCodeSizeA == 0 ||
            code.creationCodeSizeB == 0
        ) {
            revert InvalidCreationCode(id, code);
        }
        creationCodes[id] = code;
        emit SetSYCreationCode(id, code);
    }

    function deploySY(bytes32 id, bytes memory constructorParams, address syOwner) external returns (address SY) {
        CreationCode memory code = creationCodes[id];

        if (code.creationCodeContractA == address(0)) {
            revert InvalidSYId(id);
        }

        SY = BaseSplitCodeFactory._create2(
            0,
            bytes32(block.chainid),
            constructorParams,
            code.creationCodeContractA,
            code.creationCodeSizeA,
            code.creationCodeContractB,
            code.creationCodeSizeB
        );

        emit DeployedSY(id, constructorParams, SY);
        IOwnable(SY).transferOwnership(syOwner, true, false);
    }
}
