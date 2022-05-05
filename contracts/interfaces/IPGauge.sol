pragma solidity 0.8.9;
pragma abicoder v2;

interface IPGauge {
    // ============= ACTIONS =============

    function stake(address receiver) external;

    function withdraw(address receiver, uint256 amount) external;

    function redeemReward(address receiver) external returns (uint256[] memory outAmounts);

    // ============= USER INFO =============

    function balance(address user)
        external
        returns (
            uint256 lpStaked,
            uint256 activeLpAmount
        );

    // ============= META DATA =============

    function market() external view returns (address market);
}
