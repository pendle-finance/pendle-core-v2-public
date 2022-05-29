// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.9;

import "../../libraries/VeBalanceLib.sol";
import "./VotingEscrowToken.sol";
import "./CelerAbstracts/CelerReceiver.sol";

contract VotingEscrowPendleSidechain is VotingEscrowToken, CelerReceiver {
    mapping(address => address) public delegateeOf;
    mapping(address => address) public delegatorOf;

    constructor(address _governanceManager) CelerReceiver(_governanceManager) {}

    /**
     * @dev Both two types of message will contain VeBalance supply & timestamp
     * @dev If the message also contains some users' position, we should update it
     */
    function _executeMessage(bytes memory message) internal virtual override {
        (uint256 timestamp, VeBalance memory supply, bytes memory userData) = abi.decode(
            message,
            (uint256, VeBalance, bytes)
        );
        _setNewTotalSupply(timestamp, supply);
        if (userData.length > 0) {
            _executeUpdateUserBalance(userData);
        }
    }

    function _executeUpdateUserBalance(bytes memory userData) internal {
        (address delegator, address delegatee, LockedPosition memory position) = abi.decode(
            userData,
            (address, address, LockedPosition)
        );
        positionData[delegator] = position;
        delegateeOf[delegator] = delegatee;
    }

    function _setNewTotalSupply(uint256 timestamp, VeBalance memory supply) internal {
        // this should never happen
        assert(timestamp % WEEK == 0);
        lastSupplyUpdatedAt = timestamp;
        _totalSupply = supply;
    }

    function updateAndGetTotalSupply() external virtual override returns (uint256) {
        // add comments here
        return totalSupply();
    }

    function setNewDelegator(address delegator) external {
        require(delegator != address(0), "invalid delegator");
        delegatorOf[msg.sender] = delegator;
    }

    function balanceOf(address user) public view virtual override returns (uint256) {
        address delegator = delegatorOf[user];
        if (delegator == address(0) || delegator == user) {
            // in case they want to have their own vependle
            if (delegateeOf[user] != user) {
                // already delegate to some one else
                return 0;
            }
            return super.balanceOf(user);
        }

        // successfully receives delegated vebalance
        if (delegateeOf[delegator] == user) {
            return super.balanceOf(delegator);
        }

        return 0;
    }
}
