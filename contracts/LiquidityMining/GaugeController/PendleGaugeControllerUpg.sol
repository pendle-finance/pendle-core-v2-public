// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../core/libraries/BoringOwnableUpgradeableV2.sol";
import "../../core/libraries/Errors.sol";
import "../../core/libraries/math/PMath.sol";

import "../../interfaces/IPGaugeController.sol";
import "../../interfaces/IPMarket.sol";

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PendleGaugeControllerUpg is IPGaugeController, BoringOwnableUpgradeableV2, UUPSUpgradeable {
    using SafeERC20 for IERC20;
    using PMath for uint256;

    struct MarketRewardData {
        uint128 pendlePerSec;
        uint128 accumulatedPendle;
        uint128 lastUpdated;
        uint128 incentiveEndsAt;
    }

    uint256 internal constant MAX_PENDLE_PER_SEC_PER_POOL = 1e17; // i.e: 60k PENDLE per week

    // solhint-disable immutable-vars-naming
    address public immutable pendle;

    mapping(address => MarketRewardData) public rewardData;

    mapping(uint128 => bool) private __deprecated__epochRewardReceived;
    mapping(address => bool) private __deprecated__isValidMarket;

    uint256[99] private __gap;

    constructor(address _pendle) {
        pendle = _pendle;
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        __BoringOwnableV2_init(_owner);
    }

    /**
     * @dev non-market caller can also call, but just receive no rewards
     * @dev no concern on reentracy since pendle is standard ERC20
     */
    function redeemMarketReward() external {
        address market = msg.sender;
        MarketRewardData memory rwd = _getUpdatedMarketReward(market);

        uint256 amount = rwd.accumulatedPendle;

        if (amount != 0) {
            IERC20(pendle).safeTransfer(market, amount);
            emit MarketClaimReward(market, amount);
        }

        rwd.accumulatedPendle = 0;
        rewardData[market] = rwd;
    }

    function setRewardDatas(
        address[] calldata markets,
        uint128[] calldata pendlePerSecs,
        uint128[] calldata incentiveEndsAts
    ) external onlyOwner {
        if (markets.length != pendlePerSecs.length || markets.length != incentiveEndsAts.length) {
            revert Errors.ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < markets.length; ++i) {
            _setRewardData(markets[i], pendlePerSecs[i], incentiveEndsAts[i]);
        }
    }

    function withdrawPendle(uint256 amount) external onlyOwner {
        IERC20(pendle).safeTransfer(msg.sender, amount);
    }

    function _setRewardData(address market, uint128 newPendlePerSec, uint128 newIncentiveEndsAt) internal {
        uint256 expiry = IPMarket(market).expiry();
        require(block.timestamp < newIncentiveEndsAt && newIncentiveEndsAt <= expiry, "invalid incentivesEnds");

        assert(newPendlePerSec <= MAX_PENDLE_PER_SEC_PER_POOL);

        MarketRewardData memory rwd = _getUpdatedMarketReward(market);

        rewardData[market] = MarketRewardData({
            pendlePerSec: newPendlePerSec,
            accumulatedPendle: rwd.accumulatedPendle,
            lastUpdated: uint128(block.timestamp),
            incentiveEndsAt: newIncentiveEndsAt
        });

        emit UpdateMarketRewardV2(market, newPendlePerSec, newIncentiveEndsAt);
    }

    function _getUpdatedMarketReward(address market) internal view returns (MarketRewardData memory) {
        MarketRewardData memory rwd = rewardData[market];
        uint128 newLastUpdated = uint128(PMath.min(block.timestamp, rwd.incentiveEndsAt));
        rwd.accumulatedPendle += rwd.pendlePerSec * (newLastUpdated - rwd.lastUpdated);
        rwd.lastUpdated = newLastUpdated;
        return rwd;
    }

    /// ----------------- owner logic -----------------

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}
}
