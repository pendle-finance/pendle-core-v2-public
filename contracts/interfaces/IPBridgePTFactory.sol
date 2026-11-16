// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IPGovernanceProxy} from "./IPGovernanceProxy.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";

interface IPBridgePTFactory is IOAppCore {
    event PTOFTDeployed(uint32 indexed lzEid, bytes32 indexed originalPt, address indexed oft);

    event PTOFTWired(uint32 indexed hubLzEid, address indexed hubPt, uint32[] toPeerEids);

    event FactoryWired(uint32 indexed peerEid, address indexed peer);

    ////////////////////////////////////////////////////////////////////////////////
    /// Getters
    ////////////////////////////////////////////////////////////////////////////////

    function LZ_EID() external view returns (uint32);

    function GOV_PROXY() external view returns (IPGovernanceProxy);

    function HUB_PT_OFT_ADAPTER_CREATION_CODE() external view returns (address);

    function SPOKE_PT_OFT_CREATION_CODE() external view returns (address);

    function SELF_CHAIN_SHORT_NAME() external view returns (string memory);

    function OFT_PROXY_ADMIN() external view returns (address);

    function derivePtOftAddress(uint32 peerLzEid, uint32 hubLzEid, address hubPt) external view returns (address oft);

    ////////////////////////////////////////////////////////////////////////////////
    /// Deploy hub PT OFT adapter
    ////////////////////////////////////////////////////////////////////////////////

    function deployHubPtOftAdapter(address hubPt) external returns (address oft);

    ////////////////////////////////////////////////////////////////////////////////
    /// Deploy spoke PT OFT
    ////////////////////////////////////////////////////////////////////////////////

    struct SpokePtDeploymentParams {
        address hubPt;
        string name;
        string symbol;
        uint256 expiry;
        uint8 decimals;
    }

    function quoteDeploySpokePtOft(address hubPt, uint32 toPeerEid, bytes calldata options, bool payInLzToken)
        external
        view
        returns (MessagingFee memory fee);

    function deploySpokePtOft(address hubPt, uint32 toPeerEid, bytes calldata options, MessagingFee memory fee)
        external
        payable
        returns (MessagingReceipt memory msgReceipt);

    ////////////////////////////////////////////////////////////////////////////////
    /// wirePtOft on the self chain
    ////////////////////////////////////////////////////////////////////////////////

    struct WirePtOftParams {
        uint32 hubLzEid;
        address hubPt;
        uint32[] toPeerEids;
        /// @notice enforcedReceiveGas[i] is the gas limit for the receive call on toPeerEids[i];
        ///         use 0 value = use DEFAULT_PT_OFT_ENFORCED_RECEIVE_GAS
        uint128[] enforcedReceiveGas;
        bool setSendLib;
        bool setReceiveLib;
    }

    function wirePtOft(WirePtOftParams memory params) external;

    ////////////////////////////////////////////////////////////////////////////////
    /// Remote wirePtOft on the other chains
    ////////////////////////////////////////////////////////////////////////////////

    function quoteRemoteWirePtOft(
        uint32 peerEid,
        WirePtOftParams calldata wireParams,
        bytes calldata options,
        bool payInLzToken
    ) external view returns (MessagingFee memory fee);

    function remoteWirePtOft(
        uint32 peerEid,
        WirePtOftParams calldata wireParams,
        bytes calldata options,
        MessagingFee memory fee
    ) external payable returns (MessagingReceipt memory msgReceipt);

    ////////////////////////////////////////////////////////////////////////////////
    /// Self wire
    ////////////////////////////////////////////////////////////////////////////////

    struct SelfWireParams {
        uint32 peerEid;
        address peer;
        SetConfigParam[] sendConfigParam;
        SetConfigParam[] receiveConfigParam;
        bool setSendLib;
        bool setReceiveLib;
    }

    function selfWire(SelfWireParams memory params) external;

    ////////////////////////////////////////////////////////////////////////////////
    /// Remote self wire
    ////////////////////////////////////////////////////////////////////////////////

    function quoteRemoteSelfWire(
        uint32 peerEid,
        SelfWireParams calldata wireParams,
        bytes calldata options,
        bool payInLzToken
    ) external view returns (MessagingFee memory fee);

    function remoteSelfWire(
        uint32 peerEid,
        SelfWireParams calldata wireParams,
        bytes calldata options,
        MessagingFee memory fee
    ) external payable returns (MessagingReceipt memory msgReceipt);
}
