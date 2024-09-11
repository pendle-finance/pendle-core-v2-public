// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ISolvOpenFundMarket {
    struct SFTInfo {
        address manager;
        bool isValid;
    }
    struct SubscribeLimitInfo {
        uint256 hardCap;
        uint256 subscribeMin;
        uint256 subscribeMax;
        uint64 fundraisingStartTime;
        uint64 fundraisingEndTime;
    }
    struct PoolSFTInfo {
        address openFundShare;
        address openFundRedemption;
        uint256 openFundShareSlot;
        uint256 latestRedeemSlot;
    }
    struct PoolFeeInfo {
        uint16 carryRate;
        address carryCollector;
        uint64 latestProtocolFeeSettleTime;
    }
    struct ManagerInfo {
        address poolManager;
        address subscribeNavManager;
        address redeemNavManager;
    }
    struct PoolInfo {
        PoolSFTInfo poolSFTInfo;
        PoolFeeInfo poolFeeInfo;
        ManagerInfo managerInfo;
        SubscribeLimitInfo subscribeLimitInfo;
        address vault;
        address currency;
        address navOracle;
        uint64 valueDate;
        bool permissionless;
        uint256 fundraisingAmount;
    }

    function poolInfos(bytes32) external view returns (PoolInfo memory);
}
