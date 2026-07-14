// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {IPBridgeDataVerifier, BridgeInfo} from "../interfaces/IPBridgeDataVerifier.sol";
import {IBungeeSORInbox} from "./vendor/bungee/IBungeeInbox.sol";
import {
    IOFT,
    SendParam as OFTSendParam,
    MessagingFee as OFTMessagingFee
} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import {BoringOwnableUpgradeableV2} from "../core/libraries/BoringOwnableUpgradeableV2.sol";

/**
 * @notice Common things to check
 * - Sender and receiver is box itself. They should be the same.
 * - Refund address is the same as the sender/receiver.
 * - Crosschain payload should be empty to avoid further execution on destination chain.
 * - There should not be unexpected crosschain approved permission (such as Bungee's delegate).
 */
contract BridgeDataVerifier is IPBridgeDataVerifier, BoringOwnableUpgradeableV2 {
    using AddressCast for address;
    using AddressCast for bytes32;

    event EidToChainIdSet(uint256 indexed eid, uint256 indexed chainId);
    event OftToPtSet(uint256 indexed chainId, address indexed oft, address indexed pt);

    address public immutable BUNGEE_INBOX;

    mapping(uint256 chainId => mapping(address oft => address pt)) public oftToPt;
    mapping(uint256 eid => uint256 chainId) public eidToChainId;

    constructor(address bungeeInbox) {
        _disableInitializers();
        BUNGEE_INBOX = bungeeInbox;
    }

    function initialize(address owner) public initializer {
        __BoringOwnableV2_init(owner);
    }

    function verify(
        address extRouter,
        bytes calldata callData,
        uint256 nativeFee,
        address approveTo,
        BridgeInfo calldata exp
    ) external view {
        BridgeInfo memory act = parseAndCheck(extRouter, callData, nativeFee, approveTo);

        // exact match
        require(exp.originChainId == act.originChainId, "BDVerifier: originChainId exp != act");
        require(exp.destinationChainId == act.destinationChainId, "BDVerifier: destinationChainId exp != act");
        require(exp.senderReceiver == act.senderReceiver, "BDVerifier: senderReceiver exp != act");
        require(exp.inputToken == act.inputToken, "BDVerifier: inputToken exp != act");
        require(exp.outputToken == act.outputToken, "BDVerifier: outputToken exp != act");

        // bounds: actual input must not exceed expected; actual min-output must not be below expected
        require(exp.inputAmount >= act.inputAmount, "BDVerifier: inputAmount exp < act");
        require(exp.minOutputAmount <= act.minOutputAmount, "BDVerifier: minOutputAmount exp > act");
    }

    function parseAndCheck(address extRouter, bytes calldata callData, uint256 nativeFee, address approveTo)
        public
        view
        returns (BridgeInfo memory)
    {
        if (extRouter == BUNGEE_INBOX) {
            return _parseAndCheckBungeeInbox(callData, approveTo);
        }
        address pt = oftToPt[block.chainid][extRouter];
        if (pt != address(0)) {
            return _parseAndCheckLZOFTSend(pt, extRouter, callData, nativeFee, approveTo);
        }
        revert("BDVerifier: unsupported router");
    }

    function _parseAndCheckBungeeInbox(bytes calldata callData, address approveTo)
        internal
        view
        returns (BridgeInfo memory)
    {
        require(approveTo == BUNGEE_INBOX, "BDVerifier: invalid approve");
        require(bytes4(callData[:4]) == IBungeeSORInbox.createRequest.selector, "BDVerifier: invalid selector");

        (IBungeeSORInbox.SingleOutputRequest memory req, address inputRefundAddress) =
            abi.decode(callData[4:], (IBungeeSORInbox.SingleOutputRequest, address));
        IBungeeSORInbox.BasicRequest memory basicReq = req.basicReq;

        require(req.destinationPayload.length == 0, "BDVerifier: non-empty crosschain payload");
        require(basicReq.sender == basicReq.receiver, "BDVerifier: sender != receiver");
        require(inputRefundAddress == basicReq.receiver, "BDVerifier: invalid refund addr");
        require(basicReq.delegate == address(0), "BDVerifier: invalid delegate");

        return BridgeInfo({
            originChainId: basicReq.originChainId,
            destinationChainId: basicReq.destinationChainId,
            senderReceiver: basicReq.receiver,
            inputToken: basicReq.inputToken,
            inputAmount: basicReq.inputAmount,
            outputToken: basicReq.outputToken,
            minOutputAmount: basicReq.minOutputAmount
        });
    }

    function _parseAndCheckLZOFTSend(
        address pt,
        address oft,
        bytes calldata callData,
        uint256 nativeFee,
        address approveTo
    ) internal view returns (BridgeInfo memory) {
        require(approveTo == oft, "BDVerifier: invalid approve");
        require(bytes4(callData[:4]) == IOFT.send.selector, "BDVerifier: invalid selector");

        (OFTSendParam memory sendParam, OFTMessagingFee memory messagingFee, address gasRefundAddress) =
            abi.decode(callData[4:], (OFTSendParam, OFTMessagingFee, address));
        address senderReceiver = _parseBytes32ToAddress(sendParam.to);

        require(
            sendParam.composeMsg.length == 0 && sendParam.oftCmd.length == 0, "BDVerifier: non-empty crosschain payload"
        );
        require(gasRefundAddress == senderReceiver, "BDVerifier: invalid refund addr");
        require(nativeFee >= messagingFee.nativeFee, "BDVerifier: missing nativeFee");

        uint256 dstChainId = eidToChainId[sendParam.dstEid];
        address peerOft = _parseBytes32ToAddress(IOAppCore(oft).peers(sendParam.dstEid));
        address outputToken = oftToPt[dstChainId][peerOft];

        return BridgeInfo({
            originChainId: block.chainid,
            destinationChainId: dstChainId,
            senderReceiver: senderReceiver,
            inputToken: pt,
            inputAmount: sendParam.amountLD,
            outputToken: outputToken,
            minOutputAmount: sendParam.minAmountLD
        });
    }

    function _parseBytes32ToAddress(bytes32 b) internal pure returns (address res) {
        res = b.toAddress();
        require(res.toBytes32() == b, "BDVerifier: invalid EVM address");
    }

    // ========== Admin functions ==========

    function setEidToChainId(uint256 eid, uint256 chainId) external onlyOwner {
        eidToChainId[eid] = chainId;
        emit EidToChainIdSet(eid, chainId);
    }

    function setOftToPt(uint256 chainId, address oft, address pt) external onlyOwner {
        oftToPt[chainId][oft] = pt;
        emit OftToPtSet(chainId, oft, pt);
    }
}
