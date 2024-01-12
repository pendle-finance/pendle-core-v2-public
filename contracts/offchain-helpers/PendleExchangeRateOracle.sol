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
        uint64 dataBlock; // the pin block which the data is sampled at
        uint32 dataTimestamp; // block(dataBlock).timestamp
        uint32 updatedAt;
    }

    error RateRejected(uint256 oldRate, uint256 newRate, RateRejectReason reason);
    error InvalidMetadata(ExchangeRateData data);

    event RateUpdated(ExchangeRateData data);

    uint256 public constant MIN_UPDATE_TIME_GAP = 12 hours;

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

    function setExchangeRate(uint128 rate, uint64 dataBlock, uint32 dataTimestamp) external onlyOwner {
        ExchangeRateData memory newData = ExchangeRateData({
            rate: rate,
            dataBlock: dataBlock,
            dataTimestamp: dataTimestamp,
            updatedAt: uint32(block.timestamp)
        });
        _setExchangeRate(newData);
    }

    function _setExchangeRate(ExchangeRateData memory newData) internal {
        ExchangeRateData memory oldData = data;

        _validateNewRate(oldData.rate, newData.rate);
        _validateMetadata(oldData, newData);

        data = newData;
        emit RateUpdated(newData);
    }

    function _validateNewRate(uint256 oldRate, uint256 newRate) internal view {
        if (oldRate > newRate) {
            revert RateRejected(oldRate, newRate, RateRejectReason.RATE_TOO_SMALL);
        }

        if (oldRate != 0 && oldRate.mulDown(PMath.ONE + maxRateDiff) < newRate) {
            revert RateRejected(oldRate, newRate, RateRejectReason.RATE_TOO_LARGE);
        }
    }

    function _validateMetadata(ExchangeRateData memory oldData, ExchangeRateData memory newData) internal pure {
        if (
            oldData.dataBlock >= newData.dataBlock ||
            oldData.dataTimestamp >= newData.dataTimestamp ||
            oldData.updatedAt + MIN_UPDATE_TIME_GAP >= newData.updatedAt
        ) {
            revert InvalidMetadata(newData);
        }
    }
}
