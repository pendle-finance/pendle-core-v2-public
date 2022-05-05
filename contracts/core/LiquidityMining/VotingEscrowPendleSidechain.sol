// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.9;

import "../../libraries/VeBalanceLib.sol";
import "./VotingEscrowToken.sol";
import "./CelerAbstracts/CelerReceiver.sol";

contract VotingEscrowPendleSidechain is VotingEscrowToken, CelerReceiver {
    constructor(address _governanceManager) CelerReceiver(_governanceManager) {}

    /**
     * @dev Both two types of message will contain VeBalance supply & timestamp
     * @dev If the message also contains some users' position, we should update it
     */
    function _executeMessage(bytes memory message) internal virtual override {
        (uint256 timestamp, VeBalance memory supply, bytes memory userPosition) = abi.decode(
            message,
            (uint256, VeBalance, bytes)
        );
        _setNewTotalSupply(timestamp, supply);
        if (userPosition.length > 0) {
            _executeUpdateUserBalance(userPosition);
        }
    }

    function _executeUpdateUserBalance(bytes memory userPosition) internal {
        (address user, LockedPosition memory position) = abi.decode(
            userPosition,
            (address, LockedPosition)
        );

        positionData[user] = position;
    }

    function _setNewTotalSupply(uint256 timestamp, VeBalance memory supply) internal {
        // this should never happen
        assert(timestamp % WEEK == 0);

        lastSupplyUpdatedAt = timestamp;
        _totalSupply = supply;
    }

    function updateAndGetTotalSupply() external virtual override returns (uint256) {
        return totalSupply();
    }
}
