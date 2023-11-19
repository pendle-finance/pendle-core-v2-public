// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

interface IKyberLiquidityMining {
    error Forbidden();
    error EmergencyEnabled();

    error InvalidRange();
    error InvalidTime();
    error InvalidReward();

    error PositionNotEligible();
    error FarmNotFound();
    error InvalidFarm();
    error NotOwner();
    error StakeNotFound();
    error RangeNotMatch();
    error RangeNotFound();
    error PhaseSettled();
    error InvalidInput();
    error LiquidityNotMatch();
    error FailToAdd();
    error FailToRemove();
    error Expired();

    event UpdateEmergency(bool enableOrDisable);
    event UpdateTokenCode(bytes farmingTokenCode);
    event WithdrawUnusedRewards(address token, uint256 amount, address receiver);

    event AddFarm(
        uint256 indexed fId,
        address poolAddress,
        RangeInput[] ranges,
        PhaseInput phase,
        address farmingToken
    );
    event AddPhase(uint256 indexed fId, PhaseInput phase);
    event ForceClosePhase(uint256 indexed fId);
    event AddRange(uint256 indexed fId, RangeInput range);
    event RemoveRange(uint256 indexed fId, uint256 rangeId);
    event ActivateRange(uint256 indexed fId, uint256 rangeId);
    event ExpandEndTimeAndRewards(uint256 indexed fId, uint256 duration, uint256[] rewardAmounts);

    event Deposit(uint256 indexed fId, uint256 rangeId, uint256[] nftIds, address indexed depositer, address receiver);
    event UpdateLiquidity(uint256 indexed fId, uint256 nftId, uint256 liquidity);
    event Withdraw(uint256[] nftIds, address receiver);
    event WithdrawEmergency(uint256 nftId, address receiver);
    event ClaimReward(uint256 fId, uint256[] nftIds, address token, uint256 amount, address receiver);

    struct RangeInput {
        int24 tickLower;
        int24 tickUpper;
        uint32 weight;
    }

    struct RewardInput {
        address rewardToken;
        uint256 rewardAmount;
    }

    struct PhaseInput {
        uint32 startTime;
        uint32 endTime;
        RewardInput[] rewards;
    }

    struct RemoveLiquidityInput {
        uint256 nftId;
        uint128 liquidity;
    }

    struct RangeInfo {
        int24 tickLower;
        int24 tickUpper;
        uint32 weight;
        bool isRemoved;
    }

    struct PhaseInfo {
        uint32 startTime;
        uint32 endTime;
        bool isSettled;
        RewardInput[] rewards;
    }

    struct FarmInfo {
        address poolAddress;
        RangeInfo[] ranges;
        PhaseInfo phase;
        uint256 liquidity;
        address farmingToken;
        uint256[] sumRewardPerLiquidity;
        uint32 lastTouchedTime;
    }

    struct StakeInfo {
        address owner;
        uint256 fId;
        uint256 rangeId;
        uint256 liquidity;
        uint256[] lastSumRewardPerLiquidity;
        uint256[] rewardUnclaimed;
    }

    // ======== user ============
    /// @dev deposit nfts to farm
    /// @dev store curRewardPerLiq now to stake info, mint an amount of farmingToken (if needed) to msg.sender
    /// @param fId farm's id
    /// @param rangeId rangeId to add, should use quoter to get best APR rangeId
    /// @param nftIds nfts to deposit
    function deposit(uint256 fId, uint256 rangeId, uint256[] memory nftIds, address receiver) external;

    /// @dev claim reward earned for nfts
    /// @param fId farm's id
    /// @param nftIds nfts to claim
    function claimReward(uint256 fId, uint256[] memory nftIds) external;

    /// @dev withdraw nfts from farm
    /// @dev only can call by nfts's owner, also claim reward earned
    /// @dev burn an amount of farmingToken (if needed) from msg.sender
    /// @param fId farm's id
    /// @param nftIds nfts to withdraw
    function withdraw(uint256 fId, uint256[] memory nftIds) external;

    /// @dev add liquidity of nfts when liquidity already added on Elastic Pool
    /// @dev only can call by nfts's owner
    /// @dev calculate reward earned, update stakeInfo, mint an amount of farmingToken to msg.sender
    /// @param fId farm's id
    /// @param rangeId rangeId of deposited nfts
    /// @param nftIds nfts to add liquidity
    function addLiquidity(uint256 fId, uint256 rangeId, uint256[] calldata nftIds) external;

    /// @dev remove liquidity of nfts from Elastic Pool
    /// @dev only can call by nfts's owner
    /// @dev calculate reward earned, update stakeInfo, mint/burn an amount of farmingToken
    /// @param nftId id of nft to remove liquidity
    /// @param liquidity amount to remove from nft
    /// @param amount0Min min amount of token0 should receive
    /// @param amount1Min min amount of token1 should receive
    /// @param deadline deadline of remove liquidity tx
    /// @param isClaimFee is also burnRTokens or not
    function removeLiquidity(
        uint256 nftId,
        uint128 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline,
        bool isClaimFee,
        bool isReceiveNative
    ) external;

    /// @dev claim fee from Elastic Pool
    /// @dev only can call by nfts's owner
    /// @param fId farm's id
    /// @param nftIds nfts to claim
    /// @param amount0Min min amount of token0 should receive
    /// @param amount1Min min amount of token1 should receive
    /// @param deadline deadline of remove liquidity tx
    function claimFee(
        uint256 fId,
        uint256[] calldata nftIds,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline,
        bool isReceiveNative
    ) external;

    /// @dev withdraw nfts in case emergency
    /// @dev only can call by nfts's owner
    /// @dev in normal case, abandon all rewards, must return farmingToken
    /// @dev incase emergencyEnabled, bypass all calculation
    /// @param nftIds nfts to withdraw
    function withdrawEmergency(uint256[] calldata nftIds) external;

    function emergencyEnabled() external view returns (bool);

    // ======== view ============

    function getFarm(
        uint256 fId
    )
        external
        view
        returns (
            address poolAddress,
            RangeInfo[] memory ranges,
            PhaseInfo memory phase,
            uint256 liquidity,
            address farmingToken,
            uint256[] memory sumRewardPerLiquidity,
            uint32 lastTouchedTime
        );

    function getDepositedNFTs(address user) external view returns (uint256[] memory listNFTs);

    function getStake(
        uint256 nftId
    )
        external
        view
        returns (
            address owner,
            uint256 fId,
            uint256 rangeId,
            uint256 liquidity,
            uint256[] memory lastSumRewardPerLiquidity,
            uint256[] memory rewardUnclaimeds
        );
}
