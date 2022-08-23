// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../../interfaces/ICelerMessageReceiverApp.sol";
import "../../../periphery/BoringOwnableUpgradeable.sol";

// solhint-disable no-empty-blocks
/// This contract is upgradable because
/// - its constructor only sets immutable variables
/// - it has storage gaps for safe addition of future variables
/// - it inherits only upgradable contract
abstract contract CelerReceiverUpg is ICelerMessageReceiverApp, BoringOwnableUpgradeable {
    address public celerMessageBus;
    address public originAddress;
    uint256 public originChainId;

    uint256[100] private __gap;

    constructor() {}

    modifier onlyCelerOrGov() {
        require(
            msg.sender == celerMessageBus || msg.sender == owner,
            "only celer message bus or gov"
        );
        _;
    }

    function setOrigin(address _addr, uint256 _chainId) external onlyOwner {
        originAddress = _addr;
        originChainId = _chainId;
    }

    function setCelerMessageBus(address _celerMessageBus) external onlyOwner {
        celerMessageBus = _celerMessageBus;
    }

    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address /* executor */
    ) external payable onlyCelerOrGov returns (ExecutionStatus) {
        // if the message sender is not celer bus, there is no harm to have the transaction failed
        if (_sender != originAddress || _srcChainId != originChainId) {
            return ExecutionStatus.Fail;
        }
        _executeMessage(_message);
        return ExecutionStatus.Success;
    }

    function _executeMessage(bytes memory message) internal virtual;
}
