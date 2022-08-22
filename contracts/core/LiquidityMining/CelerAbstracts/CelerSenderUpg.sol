// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../../interfaces/ICelerMessageBus.sol";
import "../../../periphery/BoringOwnable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

// solhint-disable no-empty-blocks
/// This contract is upgradable because
/// - its constructor only sets immutable variables
/// - it has storage gaps for safe addition of future variables
/// - it inherits only upgradable contract
abstract contract CelerSenderUpg is BoringOwnable {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    ICelerMessageBus public celerMessageBus;

    // destinationContracts mapping contains one address for each chainId only
    EnumerableMap.UintToAddressMap internal destinationContracts;

    uint256[100] private __gap;

    modifier refundUnusedEth() {
        _;
        if (address(this).balance > 0) {
            Address.sendValue(payable(msg.sender), address(this).balance);
        }
    }

    constructor() {}

    function setCelerMessageBus(address _celerMessageBus) external onlyOwner {
        celerMessageBus = ICelerMessageBus(_celerMessageBus);
    }

    function _sendMessage(uint256 chainId, bytes memory message) internal {
        assert(destinationContracts.contains(chainId));
        address toAddr = destinationContracts.get(chainId);
        uint256 fee = celerMessageBus.calcFee(message);
        // LM contracts won't hold ETH on its own so this is fine
        require(address(this).balance >= fee, "Insufficient celer fee");
        celerMessageBus.sendMessage{ value: fee }(toAddr, chainId, message);
    }

    function _afterAddDestinationContract(address addr, uint256 chainId) internal virtual {}

    function addDestinationContract(address _address, uint256 _chainId)
        external
        payable
        onlyOwner
    {
        destinationContracts.set(_chainId, _address);
        _afterAddDestinationContract(_address, _chainId);
    }

    function getAllDestinationContracts()
        public
        view
        returns (uint256[] memory chainIds, address[] memory addrs)
    {
        uint256 length = destinationContracts.length();
        chainIds = new uint256[](length);
        addrs = new address[](length);

        for (uint256 i = 0; i < length; ++i) {
            (chainIds[i], addrs[i]) = destinationContracts.at(i);
        }
    }
}
