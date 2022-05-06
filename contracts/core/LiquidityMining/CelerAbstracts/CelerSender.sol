// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../../interfaces/ICelerMessageBus.sol";
import "../../../periphery/PermissionsV2Upg.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

abstract contract CelerSender is PermissionsV2Upg {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    ICelerMessageBus private celerMessageBus;
    EnumerableMap.UintToAddressMap internal sidechainContracts;

    constructor(address _governanceManager) PermissionsV2Upg(_governanceManager) {}

    function setCelerMessageBus(address _celerMessageBus) external onlyGovernance {
        celerMessageBus = ICelerMessageBus(_celerMessageBus);
    }

    function _sendMessage(
        address addr,
        uint256 chainId,
        bytes memory message
    ) internal {
        uint256 fee = celerMessageBus.calcFee(message);
        celerMessageBus.sendMessage{ value: fee }(addr, chainId, message);
    }

    function _afterAddSidechainContract(address addr, uint256 chainId) internal virtual {}

    function addSidechainContract(address _address, uint256 _chainId)
        external
        payable
        onlyGovernance
    {
        sidechainContracts.set(_chainId, _address);
        _afterAddSidechainContract(_address, _chainId);
    }
}
