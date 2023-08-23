pragma solidity ^0.8.0;

interface ILooksFeeSharing {
    function calculateSharesValueInLOOKS(address user) external view returns (uint256);
}
