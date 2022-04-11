// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../interfaces/IPGovernanceManager.sol";
import "../interfaces/IPPermissionsV2.sol";

abstract contract PermissionsV2 is IPermissionsV2 {
    address public immutable governanceManager;

    modifier onlyGovernance() {
        require(msg.sender == _governance(), "ONLY_GOVERNANCE");
        _;
    }

    constructor(address _governanceManager) {
        require(_governanceManager != address(0), "ZERO_ADDRESS");
        governanceManager = _governanceManager;
    }

    function _governance() internal view returns (address) {
        return IPGovernanceManager(governanceManager).governance();
    }
}
