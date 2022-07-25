// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../../interfaces/ICelerMessageBus.sol";
import "../../../periphery/PermissionsV2Upg.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

// solhint-disable no-empty-blocks
/// This contract is upgradable because
/// - its constructor only sets immutable variables
/// - it has storage gaps for safe addition of future variables
/// - it inherits only upgradable contract
abstract contract CelerSenderUpg is PermissionsV2Upg {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    ICelerMessageBus public celerMessageBus;

    EnumerableMap.UintToAddressMap internal sidechainContracts;

    uint256[100] private __gap;

    constructor(address _governanceManager) PermissionsV2Upg(_governanceManager) {}

    function setCelerMessageBus(address _celerMessageBus) external onlyGovernance {
        celerMessageBus = ICelerMessageBus(_celerMessageBus);
    }

    function _sendMessage(uint256 chainId, bytes memory message) internal {
        assert(sidechainContracts.contains(chainId));
        address toAddr = sidechainContracts.get(chainId);
        uint256 fee = celerMessageBus.calcFee(message);
        celerMessageBus.sendMessage{ value: fee }(toAddr, chainId, message);
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

    function getAllSidechainContracts()
        public
        view
        returns (uint256[] memory chainIds, address[] memory addrs)
    {
        uint256 length = sidechainContracts.length();
        chainIds = new uint256[](length);
        addrs = new address[](length);

        for (uint256 i = 0; i < length; ++i) {
            (chainIds[i], addrs[i]) = sidechainContracts.at(i);
        }
    }
}
