// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

interface ISiloLens {
    function totalDepositsWithInterest(address _silo, address _asset) external view returns (uint256 _totalDeposits);
}
