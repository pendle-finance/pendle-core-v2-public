// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../interfaces/IPMsgSendEndpoint.sol";
import "../../core/libraries/BoringOwnableUpgradeable.sol";
import "../../core/libraries/Errors.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

// solhint-disable no-empty-blocks
/// This contract is upgradable because
/// - its constructor only sets immutable variables
/// - it has storage gaps for safe addition of future variables
/// - it inherits only upgradable contract
abstract contract PendleMsgSenderAppUpg is BoringOwnableUpgradeable {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    uint256 public approxDstExecutionGas;

    IPMsgSendEndpoint public immutable pendleMsgSendEndpoint;

    // destinationContracts mapping contains one address for each chainId only
    EnumerableMap.UintToAddressMap internal destinationContracts;

    uint256[100] private __gap;

    modifier refundUnusedEth() {
        _;
        if (address(this).balance > 0) {
            Address.sendValue(payable(msg.sender), address(this).balance);
        }
    }

    constructor(address _pendleMsgSendEndpoint) {
        pendleMsgSendEndpoint = IPMsgSendEndpoint(_pendleMsgSendEndpoint);
    }

    function _sendMessage(uint256 chainId, bytes memory message) internal {
        assert(destinationContracts.contains(chainId));
        address toAddr = destinationContracts.get(chainId);
        bytes memory adapterParams = _getAdapterParams();
        uint256 fee = pendleMsgSendEndpoint.calcFee(toAddr, chainId, message, adapterParams);
        // LM contracts won't hold ETH on its own so this is fine
        if (address(this).balance < fee)
            revert Errors.InsufficientFeeToSendMsg(address(this).balance, fee);
        pendleMsgSendEndpoint.sendMessage{ value: fee }(toAddr, chainId, message, adapterParams);
    }

    function addDestinationContract(address _address, uint256 _chainId)
        external
        payable
        onlyOwner
    {
        destinationContracts.set(_chainId, _address);
        _afterAddDestinationContract(_address, _chainId);
    }

    function setApproxDstExecutionGas(uint256 gas) external onlyOwner {
        approxDstExecutionGas = gas;
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

    function _getAdapterParams() internal view returns (bytes memory) {
        uint256 gas = approxDstExecutionGas;
        if (gas == 0) revert Errors.ApproxDstExecutionGasNotSet();
        // (version, gas consumption)
        return abi.encodePacked(uint16(1), gas);
    }

    function _afterAddDestinationContract(address addr, uint256 chainId) internal virtual {}

    function _getSendMessageFee(
        address dstContract,
        uint256 chainId,
        bytes memory message
    ) internal view returns (uint256) {
        return pendleMsgSendEndpoint.calcFee(dstContract, chainId, message, _getAdapterParams());
    }
}
