// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../DistributorBase.sol";

/**
 * @dev BribeDistributor aims to fund the reward for future epochs
 */
contract BribeDistributor is DistributorBase {
    function _getLastFinishedEpoch() internal view virtual override returns (uint256) {
        return WeekMath.getCurrentWeekStart();
    }

    function _ensureFundingValidEpoch(uint256 epoch) internal view virtual override {
        if (epoch < startEpoch || !WeekMath.isValidWTime(epoch)) {
            revert Errors.BDInvalidEpoch(epoch, startEpoch);
        }
    }
}
