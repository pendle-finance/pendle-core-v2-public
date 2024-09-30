// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../../../interfaces/Pump/IPumpStaking.sol";

library PendlePumpHelperLib {
    address internal constant PUMP_STAKING = 0x1fCca65fb6Ae3b2758b9b2B394CB227eAE404e1E;
    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant PUMP_BTC = 0xF469fBD2abcd6B9de8E169d128226C0Fc90a012e;
    uint256 internal constant FEE_DENOM = 10_000;

    function _mintPumpBTC(uint256 amount) internal {
        IPumpStaking(PUMP_STAKING).stake(amount);
    }

    function _instantUnstake(uint256 amount) internal {
        IPumpStaking(PUMP_STAKING).unstakeInstant(amount);
    }

    function _previewInstantUnstake(uint256 amount) internal view returns (uint256) {
        bool onlyStakeAllowed = IPumpStaking(PUMP_STAKING).onlyAllowStake();
        uint256 maxAmountRedeemable = IPumpStaking(PUMP_STAKING).pendingStakeAmount();

        require(!onlyStakeAllowed && amount <= maxAmountRedeemable, "PumpStaking: redeem not allowed");

        uint256 feeRate = IPumpStaking(PUMP_STAKING).instantUnstakeFee();
        return amount - (amount * feeRate) / FEE_DENOM;
    }
}
