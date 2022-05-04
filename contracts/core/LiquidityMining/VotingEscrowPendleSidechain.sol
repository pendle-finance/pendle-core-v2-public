// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.9;

import "../../libraries/VeBalanceLib.sol";
import "./VotingEscrowToken.sol";
import "./CelerAbstracts/CelerReceiver.sol";

contract VotingEscrowPendleSidechain is VotingEscrowToken, CelerReceiver {
    constructor(address _governanceManager) CelerReceiver(_governanceManager) {}

    /**
     * @dev Both two types of message will contain bias and slope for total supply
     * The additional bytes data will be empty if it's a updateTotalSupply and
     * (userAddr, lockAmount, lockExpiry) of user
     */
    function _executeMessage(bytes memory message) internal virtual override {
        (UPDATE_TYPE updateType, bytes memory data) = abi.decode(message, (UPDATE_TYPE, bytes));

        if (updateType == UPDATE_TYPE.UpdateTotalSupply) {
            _executeUpdateTotalSupply(data);
        } else if (updateType == UPDATE_TYPE.UpdateUserPosition) {
            _executeUpdateUserBalance(data);
        } else {
            require(false, "invalid update type");
        }
    }

    function _executeUpdateTotalSupply(bytes memory data) internal {
        (uint256 timestamp, VeBalance memory supply) = abi.decode(data, (uint256, VeBalance));
        _setNewTotalSupply(timestamp, supply);
    }

    function _executeUpdateUserBalance(bytes memory data) internal {
        (
            uint256 timestamp,
            VeBalance memory supply,
            address user,
            LockedPosition memory position
        ) = abi.decode(data, (uint256, VeBalance, address, LockedPosition));

        _setNewTotalSupply(timestamp, supply);
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
