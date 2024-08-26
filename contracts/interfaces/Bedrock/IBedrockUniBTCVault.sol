// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBedrockUniBTCVault {
    function caps(address token) external view returns (uint256);

    function mint(address _token, uint256 _amount) external;
}
