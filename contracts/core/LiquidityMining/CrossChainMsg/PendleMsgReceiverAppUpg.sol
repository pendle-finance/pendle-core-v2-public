// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../../interfaces/IPMsgReceiverApp.sol";
import "../../../periphery/BoringOwnableUpgradeable.sol";

// solhint-disable no-empty-blocks
/// This contract is upgradable because
/// - its constructor only sets immutable variables
/// - it has storage gaps for safe addition of future variables
/// - it inherits only upgradable contract
abstract contract PendleMsgReceiverAppUpg is IPMsgReceiverApp, BoringOwnableUpgradeable {
    address public immutable pendleMsgReceiveEndpoint;

    uint256[100] private __gap;

    modifier onlyFromPendleMsgReceiveEndpoint() {
        require(msg.sender == pendleMsgReceiveEndpoint, "only pendle message receive endpoint");
        _;
    }

    constructor(address _pendleMsgReceiveEndpoint) {
        pendleMsgReceiveEndpoint = _pendleMsgReceiveEndpoint;
    }

    function executeMessage(bytes calldata message)
        external
        payable
        virtual
        onlyFromPendleMsgReceiveEndpoint
    {
        _executeMessage(message);
    }

    function _executeMessage(bytes memory message) internal virtual;
}
