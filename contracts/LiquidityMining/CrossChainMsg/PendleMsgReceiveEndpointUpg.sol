// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../interfaces/ILayerZeroEndpoint.sol";
import "../../interfaces/IPMsgReceiverApp.sol";
import "../../interfaces/ILayerZeroReceiver.sol";
import "../../core/libraries/BoringOwnableUpgradeable.sol";
import "../../core/libraries/Errors.sol";
import "./libraries/LayerZeroHelper.sol";
import "./libraries/ExcessivelySafeCall.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @dev Initially, currently we will use layer zero's default send and receive version (which is most updated)
 * So we can leave the configuration unset.
 */

contract PendleMsgReceiveEndpointUpg is
    ILayerZeroReceiver,
    Initializable,
    UUPSUpgradeable,
    BoringOwnableUpgradeable
{
    using ExcessivelySafeCall for address;

    address public immutable lzEndpoint;
    address public immutable sendEndpointAddr;
    uint64 public immutable sendEndpointChainId;

    mapping(uint16 => mapping(bytes => mapping(uint64 => bytes32))) public failedMessages;

    event MessageFailed(
        uint16 _srcChainId,
        bytes _path,
        uint64 _nonce,
        bytes _payload,
        bytes _reason
    );
    event RetryMessageSuccess(
        uint16 _srcChainId,
        bytes _path,
        uint64 _nonce,
        bytes32 _payloadHash
    );

    modifier onlyLzEndpoint() {
        if (msg.sender != address(lzEndpoint)) revert Errors.OnlyLayerZeroEndpoint();
        _;
    }

    /**
     * @dev Lz has a built-in feature for trusted receive and send endpoint
     * But in order to aim for flexibility in switching to other crosschain messaging protocol, there
     * is no harm to keep our current whitelisting mechanism.
     */
    modifier mustOriginateFromSendEndpoint(uint16 srcChainId, bytes memory path) {
        if (
            sendEndpointAddr != LayerZeroHelper._getSrcAdrressFromPath(path) ||
            sendEndpointChainId != LayerZeroHelper._getOriginalChainIds(srcChainId)
        ) revert Errors.MsgNotFromSendEndpoint(msg.sender);
        _;
    }

    constructor(
        address _lzEndpoint,
        address _sendEndpointAddr,
        uint64 _sendEndpointChainId
    ) initializer {
        lzEndpoint = _lzEndpoint;
        sendEndpointAddr = _sendEndpointAddr;
        sendEndpointChainId = _sendEndpointChainId;
    }

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _path,
        uint64 _nonce,
        bytes calldata _payload
    ) external onlyLzEndpoint mustOriginateFromSendEndpoint(_srcChainId, _path) {
        (bool success, bytes memory reason) = address(this).excessivelySafeCall(
            gasleft(),
            150,
            abi.encodeWithSelector(this.nonBlockingReceive.selector, _payload)
        );

        if (!success) {
            failedMessages[_srcChainId][_path][_nonce] = keccak256(_payload);
            emit MessageFailed(_srcChainId, _path, _nonce, _payload, reason);
        }
    }

    function retryMessage(
        uint16 _srcChainId,
        bytes calldata _path,
        uint64 _nonce,
        bytes calldata _payload
    ) public payable virtual {
        bytes32 payloadHash = failedMessages[_srcChainId][_path][_nonce];

        if (payloadHash == bytes32(0) || keccak256(_payload) != payloadHash)
            revert Errors.InvalidRetryData();

        failedMessages[_srcChainId][_path][_nonce] = bytes32(0);
        nonBlockingReceive(_payload);
        emit RetryMessageSuccess(_srcChainId, _path, _nonce, payloadHash);
    }

    /**
     * @dev LayerZero by default will stop all the incoming messages once some message failed to execute
     * In the very extreme case that it fails to deliver some message to Pendle, we still want the crosschain
     * messaging feature to keep functioning. 
     * 
     * @dev As the nature of all type of messages we have:
     * - Update vePendle totalSupply
     * - Update vePendle user balance
     * - Send voting result to GaugeController
     * 
     * There is not a need to ensure the index order of messages
     */
    function nonBlockingReceive(bytes memory payload) public {
        (address receiver, bytes memory message) = abi.decode(payload, (address, bytes));
        IPMsgReceiverApp(receiver).executeMessage(message);
    }

    function govExecuteMessage(address receiver, bytes calldata message)
        external
        payable
        onlyOwner
    {
        IPMsgReceiverApp(receiver).executeMessage(message);
    }

    function setReceiveVersion(uint16 _newVersion) external {
        ILayerZeroEndpoint(lzEndpoint).setReceiveVersion(_newVersion);
    }

    //solhint-disable-next-line
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
