// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;
import "../libraries/helpers/SSTORE2Deployer.sol";
import "../periphery/BoringOwnableUpgradeable.sol";

contract SSTORE2DeployerContract is BoringOwnableUpgradeable {
    event Deployed(string name, address addr);

    function deploy(string memory name, bytes calldata creationCode)
        external
        onlyOwner
        returns (address res)
    {
        res = SSTORE2Deployer.setCreationCode(creationCode);
        emit Deployed(name, res);
    }
}
