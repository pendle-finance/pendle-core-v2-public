// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @notice Minimal interface for Euler's `GenericFactory` (the EVault factory), as a mapping
/// of vault index to the corresponding vault address.
/// https://github.com/euler-xyz/euler-vault-kit/blob/master/src/GenericFactory/GenericFactory.sol

interface IEulerFactory {
    function proxyList(uint256 index) external view returns (address);
}
