// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "../../../interfaces/IPVotingEscrow.sol";
import "./VotingEscrowToken.sol";
import "../CelerAbstracts/CelerSender.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract VotingEscrowPendleMainchain is VotingEscrowToken, IPVotingEscrow, CelerSender {
    using SafeERC20 for IERC20;
    using VeBalanceLib for VeBalance;
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    bytes private constant EMPTY_BYTES = abi.encode();

    IERC20 public immutable pendle;

    // [timestamp] => slopeChanges
    mapping(uint128 => uint128) public slopeChanges;

    // Saving totalSupply checkpoint for each week, later can be used for reward accounting
    // [timestamp] => totalSupply
    mapping(uint128 => uint128) public totalSupplyAt;

    // Saving VeBalance checkpoint for users of each week, can later use binary search
    // to ask for their vePendle balance at any timestamp
    mapping(address => Checkpoint[]) public userCheckpoints;

    constructor(IERC20 _pendle, address _governanceManager) CelerSender(_governanceManager) {
        pendle = _pendle;
    }

    /// @notice basically a proxy function to call increaseLockPosition & broadcastUserPosition at the same time
    function increaseLockPositionAndBroadcast(
        uint128 additionalAmountToLock,
        uint128 newExpiry,
        uint256[] calldata chainIds
    ) external payable returns (uint128 newVeBalance) {
        newVeBalance = increaseLockPosition(additionalAmountToLock, newExpiry);
        broadcastUserPosition(msg.sender, chainIds);
    }

    /**
     * @notice increase the lock position of an user. Applicable even when user has no position or the
        current position has expired
     * @dev expected state changes:
        - a new lock with amount = amountToPull + amountExpired, expiry = expiry is created for msg.sender in positionData
        - pendle is taken in if necessary
        - _totalSupply, lastSupplyUpdatedAt, slopeChanges, totalSupplyAt is updated
        - a checkpoint is added
     * @dev broadcast is not bundled since it can be done anytime after
     */
    function increaseLockPosition(uint128 additionalAmountToLock, uint128 newExpiry)
        public
        returns (uint128 newVeBalance)
    {
        address user = msg.sender;
        require(
            newExpiry == WeekMath.getWeekStartTimestamp(newExpiry) && newExpiry > block.timestamp,
            "invalid newExpiry"
        );

        require(newExpiry <= block.timestamp + MAX_LOCK_TIME, "max lock time exceeded");

        uint128 newTotalAmountLocked = additionalAmountToLock + positionData[user].amount;
        require(newTotalAmountLocked > 0, "zero total amount locked");

        uint128 additionalDurationToLock = newExpiry - positionData[user].expiry;

        if (additionalAmountToLock > 0) {
            pendle.safeTransferFrom(user, address(this), additionalAmountToLock);
        }

        newVeBalance = _increasePosition(user, additionalDurationToLock, additionalAmountToLock);

        emit NewLockPosition(user, newTotalAmountLocked, newExpiry);
    }

    /**
     * @notice withdraw an expired lock position, get back all locked PENDLE
     * @dev expected state changes:
        - positionData is cleared
        - pendle is transferred out
        - _totalSupply, lastSupplyUpdatedAt, slopeChanges, totalSupplyAt all doesn't need to be updated
            since these data will automatically hold true when _updateGlobalSupply() is called
        - no checkpoint is added
     * @dev broadcast is not bundled since it can be done anytime after
     */
    function withdraw(address user) external returns (uint128 amount) {
        require(isPositionExpired(user), "position not expired");
        amount = positionData[user].amount;

        require(amount > 0, "zero position");

        delete positionData[user];

        pendle.safeTransfer(user, amount);

        emit Withdraw(user, amount);
    }

    /**
     * @notice update & return the current totalSupply
     */
    function totalSupplyCurrent() external virtual override returns (uint128) {
        (VeBalance memory supply, ) = _updateGlobalSupply();
        return supply.getCurrentValue();
    }

    function broadcastTotalSupply() public payable {
        (VeBalance memory supply, uint128 timestamp) = _updateGlobalSupply();
        uint256 length = sidechainContracts.length();

        for (uint256 i = 0; i < length; ++i) {
            (uint256 chainId, ) = sidechainContracts.at(i);
            _broadcast(chainId, timestamp, supply, EMPTY_BYTES);
        }
    }

    function broadcastUserPosition(address user, uint256[] calldata chainIds) public payable {
        require(chainIds.length != 0, "empty chainIds");
        require(user != address(0), "zero address user");

        (VeBalance memory supply, uint256 timestamp) = _updateGlobalSupply();

        for (uint256 i = 0; i < chainIds.length; ++i) {
            uint256 chainId = chainIds[i];
            require(sidechainContracts.contains(chainId), "not supported chain");
            _broadcast(chainId, timestamp, supply, abi.encode(user, positionData[user]));
        }
        emit BroadcastUserPosition(user, chainIds);
    }

    function getUserVeBalanceAt(address user, uint128 timestamp) external view returns (uint128) {
        return VeBalanceLib.getCheckpointValueAt(userCheckpoints[user], timestamp);
    }

    /**
     * @dev in case of creating a new position, position should already be set to (0, 0), and durationToIncrease = expiry
     * @dev in other cases, durationToIncrease = additional-duration and amountToIncrease = additional-pendle
     */
    function _increasePosition(
        address user,
        uint128 durationToIncrease,
        uint128 amountToIncrease
    ) internal returns (uint128) {
        LockedPosition memory oldPosition = positionData[user];

        (VeBalance memory supply, ) = _updateGlobalSupply();
        if (oldPosition.expiry > block.timestamp) {
            // remove old position not yet expired
            VeBalance memory oldBalance = convertToVeBalance(oldPosition);
            supply = supply.sub(oldBalance);
            slopeChanges[oldPosition.expiry] -= oldBalance.slope;
        }

        LockedPosition memory newPosition = LockedPosition(
            oldPosition.amount + amountToIncrease,
            oldPosition.expiry + durationToIncrease
        );

        VeBalance memory newBalance = convertToVeBalance(newPosition);
        {
            // add new position
            supply = supply.add(newBalance);
            slopeChanges[newPosition.expiry] += newBalance.slope;
        }

        _totalSupply = supply;
        positionData[user] = newPosition;
        userCheckpoints[user].push(Checkpoint(newBalance, uint128(block.timestamp)));
        return newBalance.getCurrentValue();
    }

    function _updateGlobalSupply() internal returns (VeBalance memory, uint128) {
        VeBalance memory supply = _totalSupply;
        uint128 timestamp = lastSupplyUpdatedAt;
        uint128 currentWeekStart = WeekMath.getCurrentWeekStart();

        if (timestamp >= currentWeekStart) {
            return (supply, timestamp);
        }

        while (timestamp < currentWeekStart) {
            timestamp += WEEK;
            supply = supply.sub(slopeChanges[timestamp], timestamp);
            totalSupplyAt[timestamp] = supply.getValueAt(timestamp);
        }

        _totalSupply = supply;
        lastSupplyUpdatedAt = timestamp;

        return (supply, lastSupplyUpdatedAt);
    }

    function _afterAddSidechainContract(address, uint256 chainId) internal virtual override {
        (VeBalance memory supply, uint256 timestamp) = _updateGlobalSupply();
        _broadcast(chainId, timestamp, supply, EMPTY_BYTES);
    }

    function _broadcast(
        uint256 chainId,
        uint256 timestamp,
        VeBalance memory supply,
        bytes memory userData
    ) internal {
        _sendMessage(chainId, abi.encode(timestamp, supply, userData));
    }
}
