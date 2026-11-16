// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../interfaces/IPGauge.sol";
import "../../interfaces/IPGaugeController.sol";
import "../../interfaces/IStandardizedYield.sol";

import "../RewardManager/RewardManager.sol";

abstract contract PendleGauge is RewardManager, IPGauge {
    using ArrayLib for address[];

    address private immutable SY;
    address internal immutable PENDLE;
    address internal immutable gaugeController;

    constructor(address _SY, address _gaugeController) {
        SY = _SY;
        gaugeController = _gaugeController;
        PENDLE = IPGaugeController(gaugeController).pendle();
    }

    function _redeemRewards(address user) internal virtual returns (uint256[] memory rewardsOut) {
        _updateAndDistributeRewards(user);
        rewardsOut = _doTransferOutRewards(user, user);
        emit RedeemRewards(user, rewardsOut);
    }

    function _redeemExternalReward() internal virtual override {
        IStandardizedYield(SY).claimRewards(address(this));
        IPGaugeController(gaugeController).redeemMarketReward();
    }

    function _getRewardTokens() internal view virtual override returns (address[] memory) {
        address[] memory SYRewards = IStandardizedYield(SY).getRewardTokens();
        if (SYRewards.contains(PENDLE)) return SYRewards;
        return SYRewards.append(PENDLE);
    }

    function _beforeTokenTransfer(address from, address to, uint256) internal virtual {
        _updateAndDistributeRewardsForTwo(from, to);
    }
}
