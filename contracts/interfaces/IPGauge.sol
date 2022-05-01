pragma solidity 0.8.9;
pragma abicoder v2;

interface IPendleGauge {
    // ============= ACTIONS =============

    function stake(address receiver) external;

    function withdraw(address receiver, uint256 amount) external;

    function redeemReward(address receiver) external returns (uint256 redeemedReward);

    // ============= USER INFO =============

    function readUserInfo(address user)
        external
        returns (
            uint256 lpStaked,
            uint256 activeLpAmount,
            uint256 accruedReward
        );

    // ============= META DATA =============

    function readGlobalInfo()
        external
        returns (
            uint256 totalLpStaked,
            uint256 totalActiveLp,
            uint256 pendlePerSec
        );
}
