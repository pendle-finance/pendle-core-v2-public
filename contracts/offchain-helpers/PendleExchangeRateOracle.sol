// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../core/libraries/BoringOwnableUpgradeable.sol";
import "../core/libraries/math/PMath.sol";
import "../interfaces/IPExchangeRateOracle.sol";

contract PendleExchangeRateOracle is BoringOwnableUpgradeable, IPExchangeRateOracle {
    using PMath for uint256;
    using PMath for uint128;

    enum RateRejectReason {
        RATE_TOO_SMALL,
        RATE_TOO_LARGE
    }

    struct ExchangeRateData {
        uint128 rate;
        uint96 updateBlock;
        uint32 updateTimestamp;
    }

    error RateRejected(uint256 oldRate, uint256 newRate, RateRejectReason reason);
    error InvalidMetadata(ExchangeRateData data);

    event RateUpdated(ExchangeRateData data);

    string public name;
    ExchangeRateData public data;
    uint256 public immutable maxRateDiff;

    constructor(string memory _name, uint256 _maxRateDiff) initializer {
        name = _name;
        maxRateDiff = _maxRateDiff;

        __BoringOwnable_init();
    }

    function getExchangeRate() external view returns (uint256) {
        return data.rate;
    }

    function setExchangeRate(ExchangeRateData memory newData) external onlyOwner {
        ExchangeRateData memory oldData = data;

        _validateNewRate(oldData.rate, newData.rate);
        _validateMetadata(oldData, newData);

        data = newData;
        emit RateUpdated(newData);
    }

    function _validateNewRate(uint256 oldRate, uint256 newRate) internal view {
        if (oldRate >= newRate) {
            revert RateRejected(oldRate, newRate, RateRejectReason.RATE_TOO_SMALL);
        }

        if (oldRate != 0 && oldRate.mulDown(PMath.ONE + maxRateDiff) < newRate) {
            revert RateRejected(oldRate, newRate, RateRejectReason.RATE_TOO_LARGE);
        }
    }

    function _validateMetadata(ExchangeRateData memory oldData, ExchangeRateData memory newData) internal pure {
        if (oldData.updateBlock >= newData.updateBlock || oldData.updateTimestamp >= newData.updateTimestamp) {
            revert InvalidMetadata(newData);
        }
    }
}
