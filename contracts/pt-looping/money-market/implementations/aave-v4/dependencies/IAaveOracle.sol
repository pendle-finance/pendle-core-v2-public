// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/// https://github.com/aave/aave-v4/blob/main/src/spoke/interfaces/IAaveOracle.sol
/// (and IPriceOracle.sol, which IAaveOracle extends)
/// Modifications: remove all functions except `getReservePrice`.

interface IAaveOracle {
    /// @notice Price of one whole unit of the reserve's underlying asset, scaled by `decimals()`.
    /// @dev Reverts if price <= 0.
    function getReservePrice(uint256 reserveId) external view returns (uint256);
}
