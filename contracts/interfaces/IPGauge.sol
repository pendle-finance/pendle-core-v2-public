pragma solidity 0.8.9;
pragma abicoder v2;

interface IPGauge {
    function redeemReward(address receiver) external returns (uint256[] memory);
}
