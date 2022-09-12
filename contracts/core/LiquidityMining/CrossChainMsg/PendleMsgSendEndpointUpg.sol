// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../../interfaces/IPMsgSendEndpoint.sol";
import "../../../interfaces/ICelerMessageBus.sol";
import "../../../periphery/BoringOwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract PendleMsgSendEndpointUpg is
    IPMsgSendEndpoint,
    Initializable,
    UUPSUpgradeable,
    BoringOwnableUpgradeable
{
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    ICelerMessageBus public immutable celerMessageBus;
    EnumerableMap.UintToAddressMap internal receiveEndpoints;
    mapping(address => bool) public isWhitelisted;

    modifier onlyWhitelisted() {
        require(isWhitelisted[msg.sender], "only whitelisted");
        _;
    }

    constructor(ICelerMessageBus _celerMessageBus) initializer {
        celerMessageBus = _celerMessageBus;
    }

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function calcFee(
        address dstAddress,
        uint256, /*dstChainId*/
        bytes calldata message
    ) external view returns (uint256) {
        return celerMessageBus.calcFee(abi.encode(dstAddress, message));
    }

    function sendMessage(
        address dstAddress,
        uint256 dstChainId,
        bytes calldata message
    ) external payable onlyWhitelisted {
        celerMessageBus.sendMessage(
            receiveEndpoints.get(dstChainId),
            dstChainId,
            abi.encode(dstAddress, message)
        );
    }

    function addReceiveEndpoints(address endpointAddr, uint256 endpointChainId)
        external
        payable
        onlyOwner
    {
        receiveEndpoints.set(endpointChainId, endpointAddr);
    }

    function setWhitelisted(address addr, bool status) external onlyOwner {
        isWhitelisted[addr] = status;
    }

    function getAllReceiveEndpoints()
        public
        view
        returns (uint256[] memory chainIds, address[] memory addrs)
    {
        uint256 length = receiveEndpoints.length();
        chainIds = new uint256[](length);
        addrs = new address[](length);

        for (uint256 i = 0; i < length; ++i) {
            (chainIds[i], addrs[i]) = receiveEndpoints.at(i);
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
