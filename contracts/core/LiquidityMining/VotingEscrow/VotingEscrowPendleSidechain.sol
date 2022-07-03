// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.13;

import "../../../libraries/VeBalanceLib.sol";
import "../../../libraries/math/WeekMath.sol";
import "./VotingEscrowTokenBase.sol";
import "../CelerAbstracts/CelerReceiverUpg.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// solhint-disable no-empty-blocks
contract VotingEscrowPendleSidechain is VotingEscrowTokenBase, CelerReceiverUpg {
    mapping(address => address) internal delegatorOf;

    event SetNewDelegator(address delegator, address receiver);

    event SetNewTotalSupply(VeBalance totalSupply);

    event SetNewUserPosition(LockedPosition position);

    constructor(address _governanceManager) CelerReceiverUpg(_governanceManager) {}

    function totalSupplyCurrent() external view virtual override returns (uint128) {
        return totalSupplyStored();
    }

    /**
     * @dev The mechanism of delegating is for governance to support protocol to build on top
     * This way, it is more gas efficient and does not affect the crosschain messaging cost
     */
    function setDelegatorFor(address receiver, address delegator) external onlyGovernance {
        delegatorOf[receiver] = delegator;
        emit SetNewDelegator(delegator, receiver);
    }

    /**
     * @dev Both two types of message will contain VeBalance supply & wTime
     * @dev If the message also contains some users' position, we should update it
     */
    function _executeMessage(bytes memory message) internal virtual override {
        (uint128 wTime, VeBalance memory supply, bytes memory userData) = abi.decode(
            message,
            (uint128, VeBalance, bytes)
        );
        _setNewTotalSupply(wTime, supply);
        if (userData.length > 0) {
            _setNewUserPosition(userData);
        }
    }

    function _setNewUserPosition(bytes memory userData) internal {
        (address userAddr, LockedPosition memory position) = abi.decode(
            userData,
            (address, LockedPosition)
        );
        positionData[userAddr] = position;
        emit SetNewUserPosition(position);
    }

    function _setNewTotalSupply(uint128 wTime, VeBalance memory supply) internal {
        assert(wTime == WeekMath.getWeekStartTimestamp(wTime));
        lastSupplyUpdatedAt = wTime;
        _totalSupply = supply;
        emit SetNewTotalSupply(supply);
    }

    function balanceOf(address user) public view virtual override returns (uint128) {
        address delegator = delegatorOf[user];
        if (delegatorOf[user] == address(0)) {
            return super.balanceOf(user);
        }
        return super.balanceOf(delegator);
    }
}
