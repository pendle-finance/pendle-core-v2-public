pragma solidity ^0.8.0;

interface IMUXRewardRouter {
    function vault() external view returns (address);

    function weth() external view returns (address);

    function mlp() external view returns (address);

    function mcb() external view returns (address);

    function mux() external view returns (address);

    function votingEscrow() external view returns (address);

    function mlpFeeTracker() external view returns (address);

    function mlpMuxTracker() external view returns (address);

    function veFeeTracker() external view returns (address);

    function veMuxTracker() external view returns (address);

    function mlpVester() external view returns (address);

    function muxVester() external view returns (address);

    function protocolLiquidityOwner() external view returns (address);

    function mlpDistributor() external view returns (address);

    function muxDistributor() external view returns (address);

    function setProtocolLiquidityOwner(address _protocolLiquidityOwner) external;

    function withdrawToken(address _token, address _account, uint256 _amount) external;

    // ========================== aggregated staking interfaces ==========================
    function claimableRewards(
        address account
    )
        external
        returns (
            uint256 mlpFeeAmount,
            uint256 mlpMuxAmount,
            uint256 veFeeAmount,
            uint256 veMuxAmount,
            uint256 mcbAmount
        );

    function claimAll() external;

    // ========================== mux & mcb staking interfaces ==========================
    function batchStakeMuxForAccount(
        address[] memory _accounts,
        uint256[] memory _amounts,
        uint256[] memory _unlockTime
    ) external;

    function stakeMcbForAccount(address _account, uint256 _amount) external;

    function stakeMcb(uint256 _amount, uint256 lockPeriod) external;

    function stakeMux(uint256 _amount, uint256 lockPeriod) external;

    function increaseStakeUnlockTime(uint256 lockPeriod) external;

    function unstakeMcbAndMux() external;

    function stakeMlp(uint256 _amount) external returns (uint256);

    function unstakeMlp(uint256 _amount) external returns (uint256);

    // ========================== mlp staking interfaces ==========================

    function maxVestableTokenFromMlp(address account) external view returns (uint256);

    function totalVestedTokenFromMlp(address account) external view returns (uint256);

    function claimedVestedTokenFromMlp(address account) external view returns (uint256);

    function claimableVestedTokenFromMlp(address account) external view returns (uint256);

    function depositToMlpVester(uint256 amount) external;

    function withdrawFromMlpVester() external;

    function claimFromMlp() external;

    function claimVestedTokenFromMlp(address account) external returns (uint256);

    // ========================== ve staking interfaces ==========================

    function maxVestableTokenFromVe(address account) external view returns (uint256);

    function totalVestedTokenFromVe(address account) external view returns (uint256);

    function claimedVestedTokenFromVe(address account) external view returns (uint256);

    function claimableVestedTokenFromVe(address account) external view returns (uint256);

    function claimVestedTokenFromVe(address account) external returns (uint256);

    function claimFromVe() external;

    function depositToVeVester(uint256 amount) external;

    function withdrawFromVeVester() external;

    // ========================== staking status interfaces ==========================

    function averageStakePeriod() external view returns (uint256);

    function unlockTime(address account) external view returns (uint256);

    function stakedMlpAmount(address account) external view returns (uint256);

    function votingEscrowedAmounts(address account) external view returns (uint256, uint256);

    function feeRewardRate() external view returns (uint256);

    function muxRewardRate() external view returns (uint256);

    function reservedMlpAmount(address account) external view returns (uint256);

    function mlpLockAmount(address account, uint256 amount) external view returns (uint256);

    function poolOwnedRate() external view returns (uint256);

    function votingEscrowedRate() external view returns (uint256);

    // ========================== reserved interfaces ==========================

    function compound() external;

    function compoundForAccount(address _account) external;

    function batchCompoundForAccounts(address[] memory _accounts) external;
}
