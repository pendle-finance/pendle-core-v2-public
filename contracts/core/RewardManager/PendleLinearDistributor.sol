// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../libraries/BoringOwnableUpgradeable.sol";
import "../libraries/TokenHelper.sol";
import "../libraries/math/PMath.sol";
import "../../interfaces/IPLinearDistributor.sol";

contract PendleLinearDistributor is
    UUPSUpgradeable,
    BoringOwnableUpgradeable,
    TokenHelper,
    IPLinearDistributor
{
    mapping(address => bool) internal isWhitelisted;

    // [token, addr] => distribution
    mapping(address => mapping(address => DistributionData)) public distributionDatas;

    modifier onlyWhitelisted() {
        require(isWhitelisted[msg.sender], "not whitelisted");
        _;
    }

    constructor() initializer {}

    // ----------------- core-logic ----------------------

    function vestAndClaim(
        address token,
        uint256 amountToVest,
        uint256 duration
    ) external onlyWhitelisted returns (uint256) {
        require(amountToVest > 0, "invalid amountToVest");

        (uint256 amountOut, DistributionData memory data) = _updateRewardView(token, msg.sender);
        _applyVestReward(data, amountToVest, duration);

        distributionDatas[token][msg.sender] = data;

        // dodging extreme case of amountOut = amountToVest
        if (amountOut > amountToVest) {
            _transferOut(token, msg.sender, amountOut - amountToVest);
        } else if (amountToVest > amountOut) {
            _transferIn(token, msg.sender, amountToVest - amountOut);
        }

        emit Vest(token, msg.sender, amountToVest, duration);
        emit Claim(token, msg.sender, amountOut);

        return amountOut;
    }

    function claim(address token) external onlyWhitelisted returns (uint256) {
        (uint256 amountOut, DistributionData memory data) = _updateRewardView(token, msg.sender);
        distributionDatas[token][msg.sender] = data;

        if (amountOut > 0) {
            _transferOut(token, msg.sender, amountOut);
        }

        emit Claim(token, msg.sender, amountOut);
        return amountOut;
    }

    // data.lastDistributedTime is guaranteed to be block.timestamp after calling this
    function _updateRewardView(
        address token,
        address addr
    ) internal view returns (uint256 amountOut, DistributionData memory data) {
        data = distributionDatas[token][addr];
        amountOut =
            data.rewardPerSec *
            (PMath.min(block.timestamp, data.endTime) -
                PMath.min(data.lastDistributedTime, data.endTime));
        data.lastDistributedTime = PMath.Uint32(block.timestamp);
    }

    function _applyVestReward(
        DistributionData memory data,
        uint256 amountToVest,
        uint256 duration
    ) internal view {
        // amountToVest + leftOver
        uint256 totalReward = amountToVest +
            data.rewardPerSec *
            (data.endTime - PMath.min(block.timestamp, data.endTime));
        data.endTime = PMath.Uint32(block.timestamp + duration);
        data.rewardPerSec = PMath.Uint128(totalReward / duration);
    }

    // ----------------- governance-related --------------

    function setWhitelisted(address addr, bool status) external onlyOwner {
        isWhitelisted[addr] = status;
    }

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    // ----------------- upgrade-related -----------------

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
