// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDolomiteDToken {
    function mint(uint256 _amount) external returns (uint256);

    function redeem(uint256 _dAmount) external returns (uint256);

    function underlyingToken() external returns (address);

    function marketId() external view returns (uint256);

    function DOLOMITE_MARGIN() external view returns (address);
}
