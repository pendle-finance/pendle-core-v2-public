// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IPBridgePTFactory} from "../../interfaces/IPBridgePTFactory.sol";

import {IPGovernanceProxy} from "../../interfaces/IPGovernanceProxy.sol";
import {IPPrincipalToken} from "../../interfaces/IPPrincipalToken.sol";
import {OFTAdapterImpl} from "../oftImpl/hub/OFTAdapterImpl.sol";
import {PendleBridgedPrincipalToken} from "../oftImpl/spoke/PendleBridgedPrincipalToken.sol";

import {
    ILayerZeroEndpointV2,
    IMessageLibManager
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import {
    MessagingFee,
    MessagingReceipt,
    OAppUpgradeable,
    Origin
} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {
    EnforcedOptionParam,
    IOAppOptionsType3
} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/libs/OAppOptionsType3Upgradeable.sol";
import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

contract PendleBridgePTFactory is IPBridgePTFactory, OAppUpgradeable {
    using AddressCast for address;
    using AddressCast for bytes32;
    using OptionsBuilder for bytes;

    uint32 public immutable LZ_EID;
    address public immutable LZ_SEND_ULN_302;
    address public immutable LZ_RECEIVE_ULN_302;

    IPGovernanceProxy public immutable GOV_PROXY;
    address public immutable OFT_PROXY_ADMIN;

    address public immutable HUB_PT_OFT_ADAPTER_CREATION_CODE;
    address public immutable SPOKE_PT_OFT_CREATION_CODE;
    address public immutable TRANSPARENT_PROXY_CREATION_CODE;

    // hardcoded inside SendUln302 contract
    uint32 internal constant LZ_CONFIG_TYPE_EXECUTOR = 1;
    uint32 internal constant LZ_CONFIG_TYPE_ULN = 2;

    // Hardcoded inside OFT contract. Also use as the enforced options type for this OApp
    uint16 internal constant ENFORCED_OFT_SEND_MSGTYPE = 1;

    uint128 internal constant DEFAULT_PT_OFT_ENFORCED_RECEIVE_GAS = 90_000;

    // No prior receive library to grant grace to on first wiring
    uint256 internal constant LZ_RECEIVE_LIB_GRACE_PERIOD = 0;

    // Will not be changed most of the time
    string public SELF_CHAIN_SHORT_NAME;

    constructor(
        address lzEndpoint,
        address sendUln302_,
        address receiveUln302_,
        address govProxy_,
        address oftProxyAdmin_,
        address hubPtOftAdapterCreationCode,
        address spokePtOftCreationCode,
        address transparentProxyCreationCode
    ) OAppUpgradeable(lzEndpoint) {
        LZ_EID = ILayerZeroEndpointV2(lzEndpoint).eid();
        LZ_SEND_ULN_302 = sendUln302_;
        LZ_RECEIVE_ULN_302 = receiveUln302_;

        GOV_PROXY = IPGovernanceProxy(govProxy_);
        OFT_PROXY_ADMIN = oftProxyAdmin_;

        HUB_PT_OFT_ADAPTER_CREATION_CODE = hubPtOftAdapterCreationCode;
        SPOKE_PT_OFT_CREATION_CODE = spokePtOftCreationCode;
        TRANSPARENT_PROXY_CREATION_CODE = transparentProxyCreationCode;

        _disableInitializers();
    }

    function initialize(address delegateOwner, string memory selfChainShortName) external initializer {
        __OApp_init(delegateOwner);

        _transferOwnership(delegateOwner);
        SELF_CHAIN_SHORT_NAME = selfChainShortName;
    }

    ////////////////////////////////////////////////////////////////////////////////
    /// Getters
    ////////////////////////////////////////////////////////////////////////////////

    function derivePtOftAddress(uint32 peerLzEid, uint32 hubLzEid, address hubPt) public view returns (address) {
        address peer;

        if (peerLzEid == LZ_EID) {
            peer = address(this);
        } else {
            bytes32 peerBytes32 = peers(peerLzEid);
            require(peerBytes32 != bytes32(0), "PendleBridgePTFactory: peer not set");

            peer = peerBytes32.toAddress();
        }

        bytes32 initCodeHash = keccak256(_getTransparentProxyInitCode(peer));

        return Create2.computeAddress(_oftDeploymentSalt(hubLzEid, hubPt), initCodeHash, peer);
    }

    ////////////////////////////////////////////////////////////////////////////////
    /// lzReceive
    ////////////////////////////////////////////////////////////////////////////////

    enum CrossChainMsgType {
        DEPLOY_SPOKE_PT_OFT,
        REMOTE_WIRE_PT_OFT,
        REMOTE_SELF_WIRE
    }

    function _lzReceive(
        Origin calldata origin,
        bytes32, // guid
        bytes calldata message,
        address, // executor
        bytes calldata // extraData
    )
        internal
        override
    {
        CrossChainMsgType msgType = abi.decode(message[:32], (CrossChainMsgType));

        if (msgType == CrossChainMsgType.DEPLOY_SPOKE_PT_OFT) {
            (, SpokePtDeploymentParams memory params) =
                abi.decode(message, (CrossChainMsgType, SpokePtDeploymentParams));
            _lzReceive_deploySpokePtOft(origin.srcEid, params);
        } else if (msgType == CrossChainMsgType.REMOTE_WIRE_PT_OFT) {
            (, WirePtOftParams memory params) = abi.decode(message, (CrossChainMsgType, WirePtOftParams));
            _lzReceive_remoteWirePtOft(params);
        } else if (msgType == CrossChainMsgType.REMOTE_SELF_WIRE) {
            (, SelfWireParams memory params) = abi.decode(message, (CrossChainMsgType, SelfWireParams));
            _lzReceive_remoteSelfWire(params);
        } else {
            // unreachable
            assert(false);
        }
    }

    ////////////////////////////////////////////////////////////////////////////////
    /// Deploy hub PT OFT adapter
    ////////////////////////////////////////////////////////////////////////////////

    function deployHubPtOftAdapter(address hubPt) external onlyOwner returns (address oft) {
        return _deployOft_selfGrantScopedAccesses({
            impl: _deployCreate(HUB_PT_OFT_ADAPTER_CREATION_CODE, abi.encode(hubPt, _lzEndpoint())),
            initCall: abi.encodeCall(OFTAdapterImpl.initialize, address(GOV_PROXY)),
            hubEid: LZ_EID,
            hubPt: hubPt
        });
    }

    function _deployOft_selfGrantScopedAccesses(address impl, bytes memory initCall, uint32 hubEid, address hubPt)
        internal
        returns (address oft)
    {
        oft = Create2.deploy(0, _oftDeploymentSalt(hubEid, hubPt), _getTransparentProxyInitCode(address(this)));
        ITransparentUpgradeableProxy(oft).upgradeToAndCall(impl, initCall);
        ITransparentUpgradeableProxy(oft).changeAdmin(OFT_PROXY_ADMIN);

        {
            address[] memory targets = new address[](1);
            targets[0] = oft;
            bool[] memory allowed = new bool[](1);
            allowed[0] = true;

            GOV_PROXY.modifyScopedAccess(address(this), targets, IOAppCore.setPeer.selector, allowed);
            GOV_PROXY.modifyScopedAccess(address(this), targets, IOAppOptionsType3.setEnforcedOptions.selector, allowed);
        }

        emit PTOFTDeployed(hubEid, hubPt.toBytes32(), oft);
    }

    ////////////////////////////////////////////////////////////////////////////////
    /// Deploy spoke PT OFT
    ////////////////////////////////////////////////////////////////////////////////

    function quoteDeploySpokePtOft(address hubPt, uint32 toPeerEid, bytes calldata options, bool payInLzToken)
        external
        view
        returns (MessagingFee memory fee)
    {
        return _quote({
            _dstEid: toPeerEid,
            _message: _buildDeploySpokePtOftMsg(hubPt),
            _options: options,
            _payInLzToken: payInLzToken
        });
    }

    function deploySpokePtOft(address hubPt, uint32 toPeerEid, bytes calldata options, MessagingFee memory fee)
        external
        payable
        onlyOwner
        returns (MessagingReceipt memory msgReceipt)
    {
        return _lzSend({
            _dstEid: toPeerEid,
            _message: _buildDeploySpokePtOftMsg(hubPt),
            _options: options,
            _fee: fee,
            _refundAddress: msg.sender
        });
    }

    function _lzReceive_deploySpokePtOft(uint32 hubEid, SpokePtDeploymentParams memory params) internal {
        _deployOft_selfGrantScopedAccesses({
            impl: _deployCreate(SPOKE_PT_OFT_CREATION_CODE, abi.encode(_lzEndpoint(), params.expiry, params.decimals)),
            initCall: abi.encodeCall(
                PendleBridgedPrincipalToken.initialize, (params.name, params.symbol, address(GOV_PROXY))
            ),
            hubEid: hubEid,
            hubPt: params.hubPt
        });
    }

    /// @dev Should only be called on the hub chain, where the hubPT is deployed
    function _buildDeploySpokePtOftMsg(address hubPt) internal view returns (bytes memory) {
        IPPrincipalToken pt = IPPrincipalToken(hubPt);
        string memory selfChainShortName = SELF_CHAIN_SHORT_NAME;
        SpokePtDeploymentParams memory params = SpokePtDeploymentParams({
            hubPt: hubPt,
            name: string.concat(pt.name(), " (", selfChainShortName, ")"),
            symbol: string.concat(pt.symbol(), "-(", selfChainShortName, ")"),
            expiry: pt.expiry(),
            decimals: pt.decimals()
        });
        return abi.encode(CrossChainMsgType.DEPLOY_SPOKE_PT_OFT, params);
    }

    ////////////////////////////////////////////////////////////////////////////////
    /// wirePtOft on the self chain
    ////////////////////////////////////////////////////////////////////////////////

    function wirePtOft(WirePtOftParams memory params) external onlyOwner {
        _wirePtOft(params);
    }

    function _wirePtOft(WirePtOftParams memory params) internal {
        _validateWirePtOftParams(params);
        uint256 numCallsPerPt = 4;
        if (params.setSendLib) numCallsPerPt++;
        if (params.setReceiveLib) numCallsPerPt++;
        IPGovernanceProxy.Call[] memory calls = new IPGovernanceProxy.Call[](numCallsPerPt * params.toPeerEids.length);
        address thisOft = derivePtOftAddress(LZ_EID, params.hubLzEid, params.hubPt);

        uint256 callIdx = 0;
        for (uint256 i = 0; i < params.toPeerEids.length; i++) {
            uint32 toPeerEid = params.toPeerEids[i];
            address peerOft = derivePtOftAddress(toPeerEid, params.hubLzEid, params.hubPt);

            uint128 enforcedReceiveGas = params.enforcedReceiveGas[i];
            if (enforcedReceiveGas == 0) enforcedReceiveGas = DEFAULT_PT_OFT_ENFORCED_RECEIVE_GAS;

            // setPeer
            {
                calls[callIdx].target = thisOft;
                calls[callIdx].callData = abi.encodeCall(IOAppCore.setPeer, (toPeerEid, peerOft.toBytes32()));
                callIdx++;
            }

            // setEnforcedOptions
            {
                EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](1);
                enforcedOptions[0] = EnforcedOptionParam({
                    eid: toPeerEid,
                    msgType: ENFORCED_OFT_SEND_MSGTYPE,
                    options: OptionsBuilder.newOptions()
                        .addExecutorLzReceiveOption({_gas: enforcedReceiveGas, _value: 0})
                });
                calls[callIdx].target = thisOft;
                calls[callIdx].callData = abi.encodeCall(IOAppOptionsType3.setEnforcedOptions, (enforcedOptions));
                callIdx++;
            }

            // set send lib
            if (params.setSendLib) {
                calls[callIdx].target = address(_lzEndpoint());
                calls[callIdx].callData =
                    abi.encodeCall(IMessageLibManager.setSendLibrary, (thisOft, toPeerEid, LZ_SEND_ULN_302));
                callIdx++;
            }

            // set receive lib
            if (params.setReceiveLib) {
                calls[callIdx].target = address(_lzEndpoint());
                calls[callIdx].callData = abi.encodeCall(
                    IMessageLibManager.setReceiveLibrary,
                    (thisOft, toPeerEid, LZ_RECEIVE_ULN_302, LZ_RECEIVE_LIB_GRACE_PERIOD)
                );
                callIdx++;
            }

            // setup send lib
            {
                SetConfigParam[] memory sendConfigParam = new SetConfigParam[](2);
                sendConfigParam[0] = _getSelfLzConfig(LZ_SEND_ULN_302, toPeerEid, LZ_CONFIG_TYPE_ULN);
                sendConfigParam[1] = _getSelfLzConfig(LZ_SEND_ULN_302, toPeerEid, LZ_CONFIG_TYPE_EXECUTOR);
                calls[callIdx].target = address(_lzEndpoint());
                calls[callIdx].callData =
                    abi.encodeCall(IMessageLibManager.setConfig, (thisOft, LZ_SEND_ULN_302, sendConfigParam));
                callIdx++;
            }

            // setup receive lib
            {
                SetConfigParam[] memory receiveConfigParam = new SetConfigParam[](1);
                receiveConfigParam[0] = _getSelfLzConfig(LZ_RECEIVE_ULN_302, toPeerEid, LZ_CONFIG_TYPE_ULN);
                calls[callIdx].target = address(_lzEndpoint());
                calls[callIdx].callData =
                    abi.encodeCall(IMessageLibManager.setConfig, (thisOft, LZ_RECEIVE_ULN_302, receiveConfigParam));
                callIdx++;
            }
        }

        GOV_PROXY.aggregateWithScopedAccess(calls);

        emit PTOFTWired(params.hubLzEid, params.hubPt, params.toPeerEids);
    }

    function _getSelfLzConfig(address lib, uint32 toEid, uint32 configType)
        internal
        view
        returns (SetConfigParam memory res)
    {
        res.eid = toEid;
        res.configType = configType;
        res.config = _lzEndpoint().getConfig(address(this), lib, toEid, configType);
    }

    ////////////////////////////////////////////////////////////////////////////////
    /// Remote wirePtOft on the other chains
    ////////////////////////////////////////////////////////////////////////////////

    function quoteRemoteWirePtOft(
        uint32 peerEid,
        WirePtOftParams calldata wireParams,
        bytes calldata options,
        bool payInLzToken
    ) public view returns (MessagingFee memory fee) {
        return _quote({
            _dstEid: peerEid,
            _message: _buildRemoteWirePtOftMsg(wireParams),
            _options: options,
            _payInLzToken: payInLzToken
        });
    }

    function remoteWirePtOft(
        uint32 peerEid,
        WirePtOftParams calldata wireParams,
        bytes calldata options,
        MessagingFee memory fee
    ) public payable onlyOwner returns (MessagingReceipt memory msgReceipt) {
        return _lzSend({
            _dstEid: peerEid,
            _message: _buildRemoteWirePtOftMsg(wireParams),
            _options: options,
            _fee: fee,
            _refundAddress: msg.sender
        });
    }

    function _lzReceive_remoteWirePtOft(WirePtOftParams memory wireParams) internal {
        _wirePtOft(wireParams);
    }

    function _buildRemoteWirePtOftMsg(WirePtOftParams calldata wireParams) internal pure returns (bytes memory) {
        _validateWirePtOftParams(wireParams);
        return abi.encode(CrossChainMsgType.REMOTE_WIRE_PT_OFT, wireParams);
    }

    ////////////////////////////////////////////////////////////////////////////////
    /// self wire
    ////////////////////////////////////////////////////////////////////////////////

    function selfWire(SelfWireParams memory params) external onlyOwner {
        _selfWire(params);
    }

    function _selfWire(SelfWireParams memory params) internal {
        _setPeer(params.peerEid, params.peer.toBytes32());
        if (params.setSendLib) {
            _lzEndpoint().setSendLibrary(address(this), params.peerEid, LZ_SEND_ULN_302);
        }
        if (params.setReceiveLib) {
            _lzEndpoint()
                .setReceiveLibrary(address(this), params.peerEid, LZ_RECEIVE_ULN_302, LZ_RECEIVE_LIB_GRACE_PERIOD);
        }
        _lzEndpoint().setConfig(address(this), LZ_SEND_ULN_302, params.sendConfigParam);
        _lzEndpoint().setConfig(address(this), LZ_RECEIVE_ULN_302, params.receiveConfigParam);

        emit FactoryWired(params.peerEid, params.peer);
    }

    // Source:
    // https://github.com/LayerZero-Labs/devtools/blob/128b697838f4b0fd53ae748093fd66cc409ae5c4/packages/oapp-evm-upgradeable/contracts/oapp/OAppCoreUpgradeable.sol#L75-L78
    // Change: `onlyOwner` modifier is removed
    function _setPeer(uint32 _eid, bytes32 _peer) internal {
        OAppCoreStorage storage $ = _getOAppCoreStorage();
        $.peers[_eid] = _peer;
        emit PeerSet(_eid, _peer);
    }

    ////////////////////////////////////////////////////////////////////////////////
    /// Remote self wire
    ////////////////////////////////////////////////////////////////////////////////

    function quoteRemoteSelfWire(
        uint32 peerEid,
        SelfWireParams calldata wireParams,
        bytes calldata options,
        bool payInLzToken
    ) external view returns (MessagingFee memory fee) {
        return _quote({
            _dstEid: peerEid,
            _message: _buildRemoteSelfWireMsg(wireParams),
            _options: options,
            _payInLzToken: payInLzToken
        });
    }

    function remoteSelfWire(
        uint32 peerEid,
        SelfWireParams calldata wireParams,
        bytes calldata options,
        MessagingFee memory fee
    ) external payable onlyOwner returns (MessagingReceipt memory msgReceipt) {
        return _lzSend({
            _dstEid: peerEid,
            _message: _buildRemoteSelfWireMsg(wireParams),
            _options: options,
            _fee: fee,
            _refundAddress: msg.sender
        });
    }

    function _buildRemoteSelfWireMsg(SelfWireParams memory params) internal pure returns (bytes memory message) {
        return abi.encode(CrossChainMsgType.REMOTE_SELF_WIRE, params);
    }

    function _lzReceive_remoteSelfWire(SelfWireParams memory params) internal {
        _selfWire(params);
    }

    ////////////////////////////////////////////////////////////////////////////////
    /// Initcode internal helpers
    ////////////////////////////////////////////////////////////////////////////////

    function _oftDeploymentSalt(uint32 hubEid, address hubPt) internal pure returns (bytes32) {
        return keccak256(abi.encode("PendleBridgePTFactory", hubEid, hubPt));
    }

    function _getTransparentProxyInitCode(address deployer) internal view returns (bytes memory initcode) {
        // Make the deployer both the owner and logic, then replace it later
        return abi.encodePacked(TRANSPARENT_PROXY_CREATION_CODE.code, abi.encode(deployer, deployer, bytes("")));
    }

    ////////////////////////////////////////////////////////////////////////////////
    /// Other internal helpers
    ////////////////////////////////////////////////////////////////////////////////

    // alias super's property for clarity
    function _lzEndpoint() internal view returns (ILayerZeroEndpointV2) {
        return endpoint;
    }

    function _deployCreate(address codeAddr, bytes memory params) internal returns (address deployed) {
        bytes memory initcode = abi.encodePacked(codeAddr.code, params);
        assembly {
            deployed := create(0, add(initcode, 0x20), mload(initcode))
        }
        require(deployed != address(0), "deployment failed");
    }

    function _validateWirePtOftParams(WirePtOftParams memory wireParams) internal pure {
        require(
            wireParams.toPeerEids.length == wireParams.enforcedReceiveGas.length,
            "PendleBridgePTFactory: WirePtOftParams length mismatch"
        );
    }
}
