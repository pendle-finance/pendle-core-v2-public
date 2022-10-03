// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../../interfaces/ICelerMessageReceiverApp.sol";
import "../../../interfaces/IPMsgReceiverApp.sol";
import "../../../interfaces/ICelerMessageBus.sol";
import "../../../periphery/BoringOwnableUpgradeable.sol";
import "../../../libraries/Errors.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract PendleMsgReceiveEndpointUpg is
    ICelerMessageReceiverApp,
    Initializable,
    UUPSUpgradeable,
    BoringOwnableUpgradeable
{
    ICelerMessageBus public immutable celerMessageBus;
    address public immutable sendEndpointAddr;
    uint64 public immutable sendEndpointChainId;

    modifier onlyCelerMessageBus() {
        if (msg.sender != address(celerMessageBus)) revert Errors.OnlyCelerBus();
        _;
    }

    modifier mustOriginateFromSendEndpoint(address srcAddress, uint64 srcChainId) {
        if (srcAddress != sendEndpointAddr || srcChainId != sendEndpointChainId)
            revert Errors.MsgNotFromSendEndpoint(msg.sender);
        _;
    }

    constructor(
        ICelerMessageBus _celerMessageBus,
        address _sendEndpointAddr,
        uint64 _sendEndpointChainId
    ) initializer {
        celerMessageBus = _celerMessageBus;
        sendEndpointAddr = _sendEndpointAddr;
        sendEndpointChainId = _sendEndpointChainId;
    }

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    // @notice for Celer
    function executeMessage(
        address srcAddress,
        uint64 srcChainId,
        bytes calldata message,
        address /*_executor*/
    )
        external
        payable
        onlyCelerMessageBus
        mustOriginateFromSendEndpoint(srcAddress, srcChainId)
        returns (ExecutionStatus)
    {
        (address receiver, bytes memory actualMessage) = abi.decode(message, (address, bytes));
        IPMsgReceiverApp(receiver).executeMessage(actualMessage);
        return ExecutionStatus.Success;
    }

    function govExecuteMessage(address receiver, bytes calldata message)
        external
        payable
        onlyOwner
    {
        IPMsgReceiverApp(receiver).executeMessage(message);
    }

    //solhint-disable-next-line
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
