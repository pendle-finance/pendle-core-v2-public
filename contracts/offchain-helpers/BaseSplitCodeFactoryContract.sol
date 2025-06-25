// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../core/libraries/BoringOwnableUpgradeableV2.sol";
import "../core/libraries/BaseSplitCodeFactory.sol";

contract BaseSplitCodeFactoryContract is BoringOwnableUpgradeableV2 {
    event Deployed(
        string indexed name,
        address creationCodeContractA,
        uint256 creationCodeSizeA,
        address creationCodeContractB,
        uint256 creationCodeSizeB
    );

    constructor() initializer {
        __BoringOwnableV2_init(msg.sender);
    }

    function deploy(
        string memory name,
        bytes calldata creationCode
    )
        external
        onlyOwner
        returns (
            address creationCodeContractA,
            uint256 creationCodeSizeA,
            address creationCodeContractB,
            uint256 creationCodeSizeB
        )
    {
        (creationCodeContractA, creationCodeSizeA, creationCodeContractB, creationCodeSizeB) = BaseSplitCodeFactory
            .setCreationCode(creationCode);
        emit Deployed(name, creationCodeContractA, creationCodeSizeA, creationCodeContractB, creationCodeSizeB);
    }
}
