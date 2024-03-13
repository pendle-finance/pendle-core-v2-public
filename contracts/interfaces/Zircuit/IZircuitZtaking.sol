// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IZircuitZtaking {
    function depositFor(address _token, address _for, uint256 _amount) external;

    function withdraw(address _token, uint256 _amount) external;
}
