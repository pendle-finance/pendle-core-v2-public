// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../interfaces/IPVeToken.sol";
import "../../libraries/VeBalanceLib.sol";

/**
 * @dev this contract is an abstract for its mainchain and sidechain variant
 * PRINCIPLE:
 *   - All functions implemented in this contract should be either view or pure 
 *     to ensure that no writing logic is inheritted by sidechain version
 *   - Mainchain version will handle the logic which are:
 *        + Deposit, withdraw, increase lock, increase amount
 *        + Mainchain logic will be ensured to have _totalSupply = linear sum of 
 *          all users' veBalance such that their locks are not yet expired
 *        + Mainchain contract reserves 100% the right to write on sidechain
 *        + No other transaction is allowed to write on sidechain storage
 */

abstract contract VotingEscrowToken is IPVeToken {
    using VeBalanceLib for VeBalance;

    uint256 public constant WEEK = 1 weeks;
    uint256 public constant MAX_LOCK_TIME = 104 weeks;

    struct LockedPosition {
        uint256 amount;
        uint256 expiry;
    }

    VeBalance internal _totalSupply;
    uint256 public lastSupplyUpdatedAt;
    mapping(address => LockedPosition) public positionData;

    constructor() {
        lastSupplyUpdatedAt = (block.timestamp / WEEK - 1) * WEEK;
    }

    function balanceOf(address user) public view returns (uint256) {
        return convertToVeBalance(positionData[user]).getCurrentValue();
    }

    /**
     * @dev There will be a short delay every start of the week where this function
     * will be reverted, on both mainchain & sidechain. This also implies Gauge pause.
     * This will be resolved as soon as broadcastSupply is called on mainchain
     * @dev Gauges will use updateAndGetTotalSupply to get totalSupply, this will
     * prevent the pause for gauges on mainchain.
     */
    function totalSupply() public view virtual returns (uint256) {
        require(
            lastSupplyUpdatedAt >= (block.timestamp / WEEK) * WEEK,
            "paused: total supply unupdated"
        );
        return _totalSupply.getCurrentValue();
    }

    function updateAndGetTotalSupply() external virtual returns (uint256);

    function isPositionExpired(address user) public view returns (bool) {
        return positionData[user].expiry < block.timestamp;
    }


    function convertToVeBalance(LockedPosition memory position)
        public
        pure
        returns (VeBalance memory res)
    {
        res.slope = position.amount / MAX_LOCK_TIME;
        require(res.slope > 0, "invalid slope");
        res.bias = res.slope * position.expiry;
    }
}
