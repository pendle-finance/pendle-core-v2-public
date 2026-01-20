// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {BoringOwnableUpgradeableV2} from "../../core/libraries/BoringOwnableUpgradeableV2.sol";
import {TokenHelper} from "../../core/libraries/TokenHelper.sol";
import {PMath} from "../../core/libraries/math/PMath.sol";
import {IPStakedPendle} from "../../interfaces/IPStakedPendle.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract StakedPendle is IPStakedPendle, ERC20Upgradeable, BoringOwnableUpgradeableV2, TokenHelper {
    using PMath for uint256;

    address public feeReceiver;
    address public immutable PENDLE;

    mapping(address user => UserCooldown) public userCooldown;

    uint24 public cooldownDuration;
    uint64 public instantUnstakeFeeRate; // base 1e18. 5e16 means instant unstake will have to pay 5% of the amount.

    constructor(address pendle) {
        PENDLE = pendle;
        _disableInitializers();
    }

    /// @dev reminder to also call setFeeReceiver & setCooldownDurationAndFee
    function initialize(address _owner) external initializer {
        __ERC20_init("StakedPendle", "sPENDLE");
        __BoringOwnableV2_init(_owner);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "sPendle: invalid amount");

        _transferIn(PENDLE, msg.sender, amount);
        _mint(msg.sender, amount);

        emit Staked(msg.sender, amount);
    }

    function cooldown(uint256 amount) external {
        require(amount > 0, "sPendle: invalid amount");
        require(userCooldown[msg.sender].amount == 0, "sPendle: already in cooldown");

        userCooldown[msg.sender] = UserCooldown({cooldownStart: uint104(block.timestamp), amount: amount.Uint152()});
        _burn(msg.sender, amount);

        emit CooldownInitiated(msg.sender, amount, block.timestamp);
    }

    function cancelCooldown() external {
        UserCooldown memory data = userCooldown[msg.sender];
        require(data.amount > 0, "sPendle: no cooldown");

        delete userCooldown[msg.sender];
        _mint(msg.sender, data.amount);

        emit CooldownCanceled(msg.sender, data.amount);
    }

    function finalizeCooldown() external returns (uint256 /*amount*/) {
        UserCooldown memory data = userCooldown[msg.sender];
        require(data.amount > 0, "sPendle: no cooldown");

        uint256 cooldownEnd = data.cooldownStart + cooldownDuration;
        require(block.timestamp >= cooldownEnd, "sPendle: redeem not ready");

        delete userCooldown[msg.sender];
        _transferOut(PENDLE, msg.sender, data.amount);

        emit Unstaked(msg.sender, data.amount, 0);

        return data.amount;
    }

    function instantUnstake(uint256 amount) external returns (uint256 amountAfterFee, uint256 fee) {
        require(amount > 0, "sPendle: invalid amount");

        fee = PMath.rawDivUp(amount * instantUnstakeFeeRate, PMath.ONE);
        amountAfterFee = amount - fee;

        _burn(msg.sender, amount);
        _transferOut(PENDLE, msg.sender, amountAfterFee);
        _transferOut(PENDLE, feeReceiver, fee);

        emit Unstaked(msg.sender, amountAfterFee, fee);
    }

    // ======== Misc helper functions =======

    function multicall(Call3[] calldata calls) external returns (Result[] memory res) {
        uint256 length = calls.length;
        res = new Result[](length);
        for (uint256 i = 0; i < length; i++) {
            (bool success, bytes memory result) = _delegateToSelf(calls[i].callData, calls[i].allowFailure);
            res[i] = Result(success, result);
        }
    }

    function _delegateToSelf(
        bytes memory data,
        bool allowFailure
    ) internal returns (bool success, bytes memory result) {
        (success, result) = address(this).delegatecall(data);

        if (!success && !allowFailure) {
            assembly {
                // We use Yul's revert() to bubble up errors from the target contract.
                revert(add(32, result), mload(result))
            }
        }
    }

    // ======== Admin functions ========

    function setFeeReceiver(address newFeeReceiver) external onlyOwner {
        require(newFeeReceiver != address(0), "sPendle: invalid fee receiver");

        feeReceiver = newFeeReceiver;
        emit FeeReceiverUpdated(newFeeReceiver);
    }

    function setCooldownDurationAndFee(uint24 newDuration, uint64 newInstantUnstakeFeeRate) external onlyOwner {
        require(newInstantUnstakeFeeRate <= PMath.ONE, "sPendle: invalid fee factor");
        cooldownDuration = newDuration;
        instantUnstakeFeeRate = newInstantUnstakeFeeRate;
        emit CooldownDurationAndFeeUpdated(newDuration, newInstantUnstakeFeeRate);
    }
}
