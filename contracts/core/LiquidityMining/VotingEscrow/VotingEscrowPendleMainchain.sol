// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
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

    function lock(uint128 amount, uint128 expiry) external returns (uint128) {
        address user = msg.sender;
        require(expiry % WEEK == 0 && expiry > block.timestamp, "invalid expiry");
        // as long as users' amount = 0, their expiry will also be 0
        require(positionData[user].amount == 0, "lock not withdrawed"); // inappropriate comments
        require(amount > 0, "zero amount");

        pendle.safeTransferFrom(user, address(this), amount);
        return _increasePosition(user, expiry, amount);
    }

    /**
     * @dev strict condition, user can only increase lock duration for themselves
     */
    function increaseLockDuration(uint128 duration) external returns (uint128) {
        address user = msg.sender;
        require(!isPositionExpired(user), "user position expired");
        require(duration > 0 && duration % WEEK == 0, "invalid duration"); // duration % WEEK check looks meh

        return _increasePosition(user, duration, 0);
    }

    /**
     * @dev anyone can top up one user's pendle locked amount
     // I don't like this, it's a surprising behavior
     */
    function increaseLockAmount(uint128 amount) external returns (uint128 newVeBalance) {
        address user = msg.sender;
        require(!isPositionExpired(user), "user position expired");

        require(amount > 0, "zero amount");
        pendle.safeTransferFrom(user, address(this), amount);
        return _increasePosition(user, 0, amount);
    }

    /**
     * @dev there is not a need for broadcasting in withdrawing thanks to the definition of _totalSupply
     */
    function withdraw(address user) external returns (uint128 amount) {
        require(isPositionExpired(user), "user position not expired"); // not expired, not unexpired
        amount = positionData[user].amount; // should require amount != 0
        require(amount > 0, "position already withdrawed");
        positionData[user] = LockedPosition(0, 0);
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

    function broadcastUserPoisition(address user, uint256[] calldata chainIds) external payable {
        (VeBalance memory supply, uint256 timestamp) = _updateGlobalSupply();

        for (uint256 i = 0; i < chainIds.length; ++i) {
            uint256 chainId = chainIds[i];
            require(sidechainContracts.contains(chainId), "not supported chain");
            _broadcast(
                chainId,
                timestamp,
                supply,
                abi.encode(user, positionData[user])
            );
        }
    }

    /**
     * @dev in case of creating a new position, position should already be set to (0, 0), and expiryToIncrease = expiry
     * @dev in other cases, expiryToIncrease = additional-duration and amountToIncrease = additional-pendle
     */
    function _increasePosition(
        address user,
        uint128 expiryToIncrease,
        uint128 amountToIncrease
    ) internal returns (uint128) {
        LockedPosition memory oldPosition = positionData[user];
        if (oldPosition.expiry < block.timestamp) {
            // this should not happen as the initial value and the after-withdraw value of
            // lockedPosition are always (0, 0)
            assert(oldPosition.expiry == 0 && oldPosition.amount == 0);
        }

        LockedPosition memory newPosition = LockedPosition(
            oldPosition.amount + amountToIncrease,
            oldPosition.expiry + expiryToIncrease
        );

        require(newPosition.expiry - block.timestamp <= MAX_LOCK_TIME, "max lock time exceed");

        (VeBalance memory supply, ) = _updateGlobalSupply();
        if (oldPosition.expiry > block.timestamp) {
            // remove old position not yet expired
            supply = supply.sub(convertToVeBalance(oldPosition));
            slopeChanges[oldPosition.expiry] -= oldPosition.amount / MAX_LOCK_TIME;
        }

        VeBalance memory veBalance = convertToVeBalance(newPosition);
        {
            // add new position
            slopeChanges[newPosition.expiry] += veBalance.slope;
            supply = supply.add(veBalance);
        }

        _totalSupply = supply;
        positionData[user] = newPosition;
        userCheckpoints[user].push(Checkpoint(veBalance, uint128(block.timestamp)));
        return veBalance.getCurrentValue();
    }

    function _updateGlobalSupply() internal returns (VeBalance memory, uint128) {
        // this looks damn confusing, supply & timestamp is reused
        VeBalance memory supply = _totalSupply;
        uint128 timestamp = lastSupplyUpdatedAt;

        if (timestamp + WEEK > block.timestamp) {
            return (supply, timestamp);
        }

        while (timestamp + WEEK <= block.timestamp) {
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
