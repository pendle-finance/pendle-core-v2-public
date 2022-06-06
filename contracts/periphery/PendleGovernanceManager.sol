// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.14;

contract PendleGovernanceManager {
    address public governance;
    address public pendingGovernance;

    event GovernanceTransferred(address newGovernance, address previousGovernance);

    modifier onlyGovernance() {
        require(msg.sender == governance, "ONLY_GOVERNANCE");
        _;
    }

    constructor(address _governance) {
        require(_governance != address(0), "zero address");
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
     * @param newGovernance The address to transfer ownership to.
     */
    function transferGovernance(address newGovernance) external onlyGovernance {
        require(newGovernance != address(0), "zero address");
        pendingGovernance = newGovernance;
    }
}
