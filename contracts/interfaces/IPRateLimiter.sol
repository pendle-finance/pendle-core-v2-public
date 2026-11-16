// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {RateLimitData} from "../rate-limit/RateLimitLib.sol";

interface IPRateLimiter {
    error BurnAccountNotSet(address redeemer);
    error ZeroCapacity();
    error ZeroDecayWindow();

    event RateLimitedSet(address indexed token, bool rateLimited);
    event CapacitySet(address indexed token, uint192 capacity);
    event DecayWindowSet(address indexed token, uint32 burnDecayWindow, uint32 mintDecayWindow);
    event NetBurnReset(address indexed token);
    event BurnQuotaSet(address indexed token, address indexed account, uint256 amount);
    event BurnQuotaUsed(address indexed token, address indexed account, uint256 used);
    event TrustedRedeemerSet(address indexed redeemer, bool trusted);

    function ROUTER() external view returns (address);
    function PRICE_REGISTRY() external view returns (address);

    function onMint(address caller, uint256 amount) external;
    function onBurn(address caller, uint256 amount) external;

    function isRateLimited(address token) external view returns (bool);
    /// @notice Per-token meters are in SY shares; address(0) keys the aggregate meter, in 18-decimal USD.
    function getRateLimitData(address token) external view returns (RateLimitData memory);
    /// @notice A burn must also clear availableBurn(address(0)) for its USD value.
    function availableBurn(address token) external view returns (uint256);
    function burnQuota(address token, address account) external view returns (uint256);
    function isTrustedRedeemer(address redeemer) external view returns (bool);

    /// @notice Sets all meter parameters and enables limiting for `token` in one call.
    function configure(address token, uint192 capacity, uint32 burnDecayWindow, uint32 mintDecayWindow) external;
    function disable(address token) external;
    function setCapacity(address token, uint192 capacity) external;
    function setDecayWindow(address token, uint32 burnDecayWindow, uint32 mintDecayWindow) external;
    function resetNetBurn(address token) external;
    function setBurnQuota(address token, address account, uint256 amount) external;
    function setTrustedRedeemer(address redeemer, bool trusted) external;
}
