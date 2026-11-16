// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {BoringOwnableUpgradeableV2} from "../core/libraries/BoringOwnableUpgradeableV2.sol";
import {PMath} from "../core/libraries/math/PMath.sol";
import {IPRateLimiter} from "../interfaces/IPRateLimiter.sol";
import {IPTokenPriceRegistry} from "../interfaces/IPTokenPriceRegistry.sol";
import {IPTrustedRedeemer} from "../interfaces/IPTrustedRedeemer.sol";
import {RateLimitData} from "./RateLimitLib.sol";

contract PendleRateLimiter is IPRateLimiter, BoringOwnableUpgradeableV2 {
    using PMath for uint256;

    address internal constant AGGREGATE = address(0);

    address public immutable ROUTER;
    address public immutable PRICE_REGISTRY;

    mapping(address token => bool) public isRateLimited;
    // per-token meters in shares, the AGGREGATE meter in USD
    mapping(address token => RateLimitData) internal _rateLimitData;
    mapping(address token => mapping(address account => uint256)) public burnQuota;
    mapping(address redeemer => bool) public isTrustedRedeemer;

    /// @dev no-op rather than revert: the limiter must never brick an SY
    modifier ifRateLimited() {
        if (!isRateLimited[msg.sender]) return;
        _;
    }

    constructor(address _ROUTER, address _PRICE_REGISTRY) {
        _disableInitializers();
        ROUTER = _ROUTER;
        PRICE_REGISTRY = _PRICE_REGISTRY;
    }

    function initialize(address _owner) external initializer {
        __BoringOwnableV2_init(_owner);
    }

    // ----------------- SY HOOKS -----------------

    function onMint(address, uint256 amount) external ifRateLimited {
        address token = msg.sender;
        _rateLimitData[token].recordMint(amount);
        _rateLimitData[AGGREGATE].recordMint(_toUsd(token, amount));
    }

    function onBurn(address caller, uint256 amount) external ifRateLimited {
        address token = msg.sender;
        address account = _resolveAccount(caller);
        uint256 metered = amount - _useBurnQuota(token, account, amount);

        _rateLimitData[token].recordBurn(metered, token, account, false);
        _rateLimitData[AGGREGATE].recordBurn(_toUsd(token, metered), token, account, true);
    }

    /// @dev unpriced tokens (price 0) never touch the aggregate meter
    function _toUsd(address token, uint256 amount) internal view returns (uint256) {
        return amount.mulDown(IPTokenPriceRegistry(PRICE_REGISTRY).tokenPrice(token));
    }

    function _resolveAccount(address caller) internal view returns (address account) {
        if (!_isTrusted(caller)) return caller;
        account = IPTrustedRedeemer(caller).burnAccount();
        require(account != address(0), BurnAccountNotSet(caller));
    }

    /// @dev ROUTER is checked first so the common path costs no storage read
    function _isTrusted(address caller) internal view returns (bool) {
        return caller == ROUTER || isTrustedRedeemer[caller];
    }

    function _useBurnQuota(address token, address account, uint256 amount) internal returns (uint256 used) {
        uint256 quota = burnQuota[token][account];
        if (quota == 0) return 0;

        used = PMath.min(amount, quota);
        burnQuota[token][account] = quota - used;
        emit BurnQuotaUsed(token, account, used);
    }

    // ----------------- VIEWS -----------------

    function getRateLimitData(address token) external view returns (RateLimitData memory) {
        return _rateLimitData[token];
    }

    function availableBurn(address token) external view returns (uint256) {
        return _rateLimitData[token].availableBurn();
    }

    // ----------------- ADMIN FUNCTIONS -----------------

    function configure(address token, uint192 capacity, uint32 burnDecayWindow, uint32 mintDecayWindow)
        external
        onlyOwner
    {
        _setCapacity(token, capacity);
        _setDecayWindow(token, burnDecayWindow, mintDecayWindow);
        isRateLimited[token] = true;
        emit RateLimitedSet(token, true);
    }

    function disable(address token) external onlyOwner {
        isRateLimited[token] = false;
        emit RateLimitedSet(token, false);
    }

    function setCapacity(address token, uint192 capacity) external onlyOwner {
        _setCapacity(token, capacity);
    }

    function setDecayWindow(address token, uint32 burnDecayWindow, uint32 mintDecayWindow) external onlyOwner {
        _setDecayWindow(token, burnDecayWindow, mintDecayWindow);
    }

    function resetNetBurn(address token) external onlyOwner {
        _rateLimitData[token].resetNetBurn();
        emit NetBurnReset(token);
    }

    function setBurnQuota(address token, address account, uint256 amount) external onlyOwner {
        burnQuota[token][account] = amount;
        emit BurnQuotaSet(token, account, amount);
    }

    function setTrustedRedeemer(address redeemer, bool trusted) external onlyOwner {
        isTrustedRedeemer[redeemer] = trusted;
        emit TrustedRedeemerSet(redeemer, trusted);
    }

    function _setCapacity(address token, uint192 capacity) internal {
        require(capacity != 0, ZeroCapacity());
        _rateLimitData[token].setCapacity(capacity);
        emit CapacitySet(token, capacity);
    }

    function _setDecayWindow(address token, uint32 burnDecayWindow, uint32 mintDecayWindow) internal {
        require(burnDecayWindow != 0 && mintDecayWindow != 0, ZeroDecayWindow());
        _rateLimitData[token].setDecayWindow(burnDecayWindow, mintDecayWindow);
        emit DecayWindowSet(token, burnDecayWindow, mintDecayWindow);
    }
}
