// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEtherFiLiquidityPool {
    function totalValueOutOfLp() external view returns (uint128);
    function totalValueInLp() external view returns (uint128);
    function getTotalEtherClaimOf(address _user) external view returns (uint256);
    function getTotalPooledEther() external view returns (uint256);
    function sharesForAmount(uint256 _amount) external view returns (uint256);
    function sharesForWithdrawalAmount(uint256 _amount) external view returns (uint256);
    function amountForShare(uint256 _share) external view returns (uint256);

    // function deposit() external payable returns (uint256);
    function deposit(address _referral) external payable returns (uint256);
    // function deposit(address _user, address _referral) external payable returns (uint256);
}
