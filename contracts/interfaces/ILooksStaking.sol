pragma solidity ^0.8.0;

interface ILooksStaking {
    function totalShares() external view returns (uint256);

    function deposit(uint256 amount) external;

    function userInfo(address user) external view returns (uint256);

    function withdraw(uint256 shares) external;

    function harvestAndSellAndCompound() external;
}
