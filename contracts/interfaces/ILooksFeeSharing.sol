pragma solidity 0.8.17;

interface ILooksFeeSharing {
    function calculateSharesValueInLOOKS(address user) external view returns (uint256);
}
