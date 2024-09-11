// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ISolvRouter {
    function createSubscription(bytes32 poolId_, uint256 currencyAmount_) external returns (uint256 shareValue_);
}
