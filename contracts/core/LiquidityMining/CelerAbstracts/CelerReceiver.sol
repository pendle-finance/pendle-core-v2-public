// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../../interfaces/ICelerMessageReceiverApp.sol";
import "../../../periphery/PermissionsV2Upg.sol";

abstract contract CelerReceiver is ICelerMessageReceiverApp, PermissionsV2Upg {
    address public celerMessageBus;
    address public originAddress;
    uint256 public originChainId;

    constructor(address _governanceManager) PermissionsV2Upg(_governanceManager) {}

    function setOrigin(address _addr, uint256 _chainId) external onlyGovernance {
        originAddress = _addr;
        originChainId = _chainId;
    }

    function setCelerMessageBus(address _celerMessageBus) external onlyGovernance {
        celerMessageBus = _celerMessageBus;
    }

    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address /* executor */
    ) external payable returns (ExecutionStatus) {
        // if the message sender is not celer bus, there is no harm to have the transcation failed
        require(msg.sender == celerMessageBus, "only allow celer message bus");

        if (_sender != originAddress || _srcChainId != originChainId) {
            return ExecutionStatus.Fail;
        }
        _executeMessage(_message);
        return ExecutionStatus.Success;
    }

    function _executeMessage(bytes memory message) internal virtual;
}
