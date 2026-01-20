// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IPStakedPendle {
    struct Call3 {
        bool allowFailure;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    struct UserCooldown {
        uint104 cooldownStart;
        uint152 amount;
    }

    event CooldownDurationAndFeeUpdated(uint24 newDuration, uint64 instantUnstakeFeeRate);

    event Staked(address indexed user, uint256 amount);

    event Unstaked(address indexed user, uint256 amountAfterFee, uint256 fee);

    event CooldownCanceled(address indexed user, uint256 amount);

    event CooldownInitiated(address indexed user, uint256 amount, uint256 cooldownStart);

    event FeeReceiverUpdated(address indexed feeReceiver);

    // ======== Getters ========

    function PENDLE() external view returns (address);

    function cooldownDuration() external view returns (uint24);

    function instantUnstakeFeeRate() external view returns (uint64);

    function feeReceiver() external view returns (address);

    // ======== Staking functions ========

    function userCooldown(address user) external view returns (uint104 cooldownStart, uint152 amount);

    function stake(uint256 amount) external;

    function cooldown(uint256 amount) external;

    function cancelCooldown() external;

    // fee-free, after cooldown
    function finalizeCooldown() external returns (uint256 amount);

    // instant, but with fee
    function instantUnstake(uint256 amount) external returns (uint256 amountAfterFee, uint256 fee);

    // ======== Misc helper functions =======

    function multicall(Call3[] calldata calls) external returns (Result[] memory res);

    // ======== Admin functions ========

    function setCooldownDurationAndFee(uint24 newDuration, uint64 newInstantUnstakeFeeRate) external;

    function setFeeReceiver(address newFeeReceiver) external;
}
