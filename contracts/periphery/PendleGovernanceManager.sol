// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

contract PendleGovernanceManager {
    address public governance;
    address public pendingGovernance;

    event GovernanceTransferred(address newGovernance, address previousGovernance);

    modifier onlyGovernance() {
        require(msg.sender == governance, "ONLY_GOVERNANCE");
        _;
    }

    constructor(address _governance) {
        governance = _governance;
    }

    /**
     * @dev Allows the pendingGovernance address to finalize the change governance process.
     */
    function claimGovernance() external {
        require(pendingGovernance == msg.sender, "FORBIDDEN");
        emit GovernanceTransferred(pendingGovernance, governance);
        governance = pendingGovernance;
        pendingGovernance = address(0);
    }

    /**
     * @dev Allows the current governance to set the pendingGovernance address.
     * @param _governance The address to transfer ownership to.
     */
    function transferGovernance(address _governance) external onlyGovernance {
        pendingGovernance = _governance;
    }
}
