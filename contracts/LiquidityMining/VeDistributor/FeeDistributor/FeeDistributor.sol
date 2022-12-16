// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../DistributorBase.sol";

/**
 * @dev Fee distributor aims to distribute governance's fee in USDC
 * Thus there might be a delay in governance's action for fee accounting
 * 
 * Hence, governance reserves the permission to set which epoch is finished
 */
contract FeeDistributor is DistributorBase {
    uint256 public lastFinishedEpoch;

    function setLastFinishedEpoch(uint256 newLastFinishedEpoch) external {
        if (!IPFeeDistributorFactory(factory).isAdmin(msg.sender)) {
            revert Errors.FDNotAdmin();
        }
        lastFinishedEpoch = newLastFinishedEpoch;
    }

    function _getLastFinishedEpoch() internal view virtual override returns (uint256) {
        return lastFinishedEpoch;
    }

    function _ensureFundingValidEpoch(
        uint256 epoch
    ) internal view virtual override {
        uint256 currentWeekStart = WeekMath.getCurrentWeekStart();
        // There should not be reward for current week yet
        if (epoch < startEpoch || epoch > currentWeekStart || !WeekMath.isValidWTime(epoch)) {
            revert Errors.FDInvalidEpoch(epoch, startEpoch, currentWeekStart);
        }
    }

    uint256[100] private _gaps;
}
