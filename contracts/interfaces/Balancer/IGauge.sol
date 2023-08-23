// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IGauge {
    function claim_rewards(address _addr, address _receiver) external;

    function reward_count() external view returns (uint256);

    function reward_tokens(uint256 arg0) external view returns (address);
}
