// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPLPWrapperFactory {
    function createOrGet(address _lpToken) external returns (address wrapper);

    function setRewardReceiver(address _rewardReceiver) external;

    function rewardReceiver() external view returns (address);
}
