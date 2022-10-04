// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../interfaces/IPMsgReceiverApp.sol";
import "../../core-libraries/BoringOwnableUpgradeable.sol";
import "../../core-libraries/Errors.sol";

// solhint-disable no-empty-blocks
/// This contract is upgradable because
/// - its constructor only sets immutable variables
/// - it has storage gaps for safe addition of future variables
/// - it inherits only upgradable contract
abstract contract PendleMsgReceiverAppUpg is IPMsgReceiverApp, BoringOwnableUpgradeable {
    address public immutable pendleMsgReceiveEndpoint;

    uint256[100] private __gap;

    modifier onlyFromPendleMsgReceiveEndpoint() {
        if (msg.sender != pendleMsgReceiveEndpoint)
            revert Errors.MsgNotFromReceiveEndpoint(msg.sender);
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
