// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IPossibleSupplyCapInterface {
    function getAbsoluteSupplyCap() external view returns (uint256);

    function getAbsoluteTotalSupply() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function supplyCap() external view returns (uint256);
}

contract SupplyCapReader {
    function read(address syAddr) external view returns (uint256 currentSupply, uint256 supplyCap) {
        IPossibleSupplyCapInterface sy = IPossibleSupplyCapInterface(syAddr);
        try sy.getAbsoluteSupplyCap() returns (uint256 res) {
            supplyCap = res;
            currentSupply = sy.getAbsoluteTotalSupply();
        } catch {
            supplyCap = sy.supplyCap();
            currentSupply = sy.totalSupply();
        }
    }
}
