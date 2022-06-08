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

    mapping(uint128 => uint128) private slopeChanges;

    // Saving totalSupply checkpoint for each week, later can be used for reward accounting
    mapping(uint128 => uint128) public totalSupplyAt;

    // Saving VeBalance checkpoint for users of each week, can later use binary search
    // to ask for their vePendle balance at any timestamp
    mapping(address => Checkpoint[]) public userCheckpoints;

    constructor(IERC20 _pendle, address _governanceManager) CelerSender(_governanceManager) {
        pendle = _pendle;
    }

    function lock(uint128 amountToPull, uint128 expiry) external returns (uint128 newVeBalance) {
        require(
            expiry == WeekMath.getWeekStartTimestamp(expiry) && expiry > block.timestamp,
            "invalid expiry"
        );
        require(expiry <= block.timestamp + MAX_LOCK_TIME, "max lock time exceeded");

        address user = msg.sender;
        require(isPositionExpired(user), "old lock not expired"); // inappropriate comments

        uint128 amountToLock = amountToPull + _getRenewingLockAmount(user);
        require(amountToLock > 0, "zero amount");

        if (amountToPull > 0) {
            pendle.safeTransferFrom(user, address(this), amountToPull);
        }
        newVeBalance = _increasePosition(user, expiry, amountToLock);
    }

    /**
     * @dev strict condition, user can only increase lock duration for themselves
     */
    function increaseLockDuration(uint128 duration) external returns (uint128 newVeBalance) {
        address user = msg.sender;
        require(!isPositionExpired(user), "user position expired");
        require(duration > 0 && WeekMath.isValidDuration(duration), "invalid duration"); // duration % WEEK check looks meh
        require(
            positionData[user].expiry + duration <= block.timestamp + MAX_LOCK_TIME,
            "max lock time exceeded"
        );

        newVeBalance = _increasePosition(user, duration, 0);
    }

    /**
     * @dev anyone can top up one user's pendle locked amount
     */
    function increaseLockAmount(uint128 amount) external returns (uint128 newVeBalance) {
        address user = msg.sender;
        require(!isPositionExpired(user), "user position expired");

        require(amount > 0, "zero amount");
        pendle.safeTransferFrom(user, address(this), amount);
        newVeBalance = _increasePosition(user, 0, amount);
    }

    /**
     * @dev there is not a need for broadcasting in withdrawing thanks to the definition of _totalSupply
     */
    function withdraw(address user) external returns (uint128 amount) {
        require(isPositionExpired(user), "user position not expired"); // not expired, not unexpired
        amount = positionData[user].amount; // should require amount != 0
        require(amount > 0, "position already withdrawed");
        delete positionData[user];
        pendle.safeTransfer(user, amount);
    }

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

    function broadcastUserPosition(address user, uint256[] calldata chainIds) external payable {
        (VeBalance memory supply, uint256 timestamp) = _updateGlobalSupply();

        for (uint256 i = 0; i < chainIds.length; ++i) {
            uint256 chainId = chainIds[i];
            require(sidechainContracts.contains(chainId), "not supported chain");
            _broadcast(chainId, timestamp, supply, abi.encode(user, positionData[user]));
        }
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
        // this looks damn confusing, supply & timestamp is reused
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

    function _getRenewingLockAmount(address user) internal returns (uint128 amount) {
        amount = positionData[user].amount;
        positionData[user] = LockedPosition(0, 0);
    }
}
