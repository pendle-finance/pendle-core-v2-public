// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "../../interfaces/IPVotingEscrow.sol";
import "./VotingEscrowToken.sol";
import "./CelerAbstracts/CelerSender.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract VotingEscrowPendleMainchain is VotingEscrowToken, IPVotingEscrow, CelerSender {
    using SafeERC20 for IERC20;
    using VeBalanceLib for VeBalance;
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    bytes private constant EMPTY_BYTES = abi.encode();

    IERC20 public immutable pendle;

    // Each user has a set of chain they are interested in
    mapping(address => EnumerableMap.UintToAddressMap) private userChains;

    mapping(uint256 => uint256) private slopeChanges;

    // Saving totalSupply checkpoint for each week, later can be used for reward accounting
    mapping(uint256 => uint256) public totalSupplyAt;

    // Saving VeBalance checkpoint for users of each week, can later use binary search
    // to ask for their vePendle balance at any timestamp
    mapping(address => Checkpoint[]) public userCheckpoints;

    constructor(IERC20 _pendle, address _governanceManager) CelerSender(_governanceManager) {
        pendle = _pendle;
    }

    function lock(uint256 amount, uint256 expiry) external payable returns (uint256) {
        address user = msg.sender;
        require(expiry % WEEK == 0 && expiry > block.timestamp, "invalid expiry");
        // as long as users' amount = 0, their expiry will also be 0
        require(positionData[user].amount == 0, "lock not expired or withdrawed"); // inappropriate comments
        require(amount > 0, "zero amount");

        pendle.safeTransferFrom(user, address(this), amount);
        return _increasePosition(user, expiry, amount);
    }

    /**
     * @dev strict condition, user can only increase lock duration for themselves
     */
    function increaseLockDuration(uint256 duration) external payable returns (uint256) {
        address user = msg.sender;
        require(!isPositionExpired(user), "user position expired");
        require(duration > 0 && duration % WEEK == 0, "invalid duration"); // duration % WEEK check looks meh

        return _increasePosition(user, duration, 0);
    }

    /**
     * @dev anyone can top up one user's pendle locked amount
     // I don't like this, it's a surprising behavior
     */
    function increaseLockAmount(address user, uint256 amount)
        external
        payable
        returns (uint256 newVeBalance)
    {
        require(!isPositionExpired(user), "user position expired");

        require(amount > 0, "zero amount");
        pendle.safeTransferFrom(msg.sender, address(this), amount);

        return _increasePosition(user, 0, amount);
    }

    /**
     * @dev there is not a need for broadcasting in withdrawing thanks to the definition of _totalSupply
     */
    function withdraw(address user) external returns (uint256 amount) {
        require(isPositionExpired(user), "user position unexpired"); // not expired, not unexpired
        amount = positionData[user].amount; // should require amount != 0

        if (amount > 0) {
            positionData[user] = LockedPosition(0, 0);
            pendle.safeTransfer(user, amount);
        }
    }

    function updateAndGetTotalSupply() external virtual override returns (uint256) {
        (VeBalance memory supply, ) = _updateGlobalSupply();
        return supply.getCurrentValue();
    }

    function broadcastTotalSupply() public payable {
        (VeBalance memory supply, uint256 timestamp) = _updateGlobalSupply();
        uint256 length = sidechainContracts.length();

        for (uint256 i = 0; i < length; ++i) {
            (uint256 chainId, ) = sidechainContracts.at(i);
            _broadcast(chainId, timestamp, supply, EMPTY_BYTES);
        }
    }

    function setUserCrosschainAddr(uint256 chainId, address delegatee) external payable {
        // huh why payable
        address user = msg.sender;
        require(delegatee != address(0), "invalid delegatee");
        require(sidechainContracts.contains(chainId), "chain not supported");
        userChains[user].set(chainId, delegatee);
        if (!isPositionExpired(user)) {
            // these hooks are out of nowhere
            _afterModifyUserInfo(user, chainId, delegatee);
        }
    }

    function removeUserCrosschainAddr(uint256 chainId) external {
        address user = msg.sender;
        require(userChains[user].contains(chainId), "chain not exists in preference");
        userChains[user].remove(chainId);
    }

    /**
     * @dev in case of creating a new position, position should already be set to (0, 0), and expiryToIncrease = expiry
     * @dev in other cases, expiryToIncrease = additional-duration and amountToIncrease = additional-pendle
     */
    function _increasePosition(
        address user,
        uint256 expiryToIncrease,
        uint256 amountToIncrease
    ) internal returns (uint256) {
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

        (VeBalance memory supply, uint256 timestamp) = _updateGlobalSupply();
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
        userCheckpoints[user].push(Checkpoint(veBalance, block.timestamp));

        _broadcastPosition(user, newPosition, timestamp, supply);
        return veBalance.getCurrentValue();
    }

    function _updateGlobalSupply() internal returns (VeBalance memory supply, uint256 timestamp) {
        // this looks damn confusing, supply & timestamp is reused
        supply = _totalSupply;
        timestamp = lastSupplyUpdatedAt;

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
    }

    function _broadcastPosition(
        address user,
        LockedPosition memory position,
        uint256 timestamp,
        VeBalance memory supply
    ) internal {
        uint256 length = userChains[user].length();
        for (uint256 i = 0; i < length; ++i) {
            (uint256 chainId, address delegatee) = userChains[user].at(i);
            _broadcast(chainId, timestamp, supply, abi.encode(user, delegatee, position));
        }
    }

    function _afterAddSidechainContract(address, uint256 chainId) internal virtual override {
        (VeBalance memory supply, uint256 timestamp) = _updateGlobalSupply();
        _broadcast(chainId, timestamp, supply, EMPTY_BYTES);
    }

    function _afterModifyUserInfo(
        address user,
        uint256 chainId,
        address delegatee
    ) internal {
        if (isPositionExpired(user)) return;

        LockedPosition memory position = positionData[user];
        (VeBalance memory supply, uint256 timestamp) = _updateGlobalSupply();
        _broadcast(chainId, timestamp, supply, abi.encode(user, delegatee, position));
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
