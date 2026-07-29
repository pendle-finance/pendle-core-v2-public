// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

/// https://github.com/euler-xyz/euler-vault-kit/blob/5b98b42048ba11ae82fb62dfec06d1010c8e41e6/src/interfaces/IPriceOracle.sol#L4
/// Modifications:
/// - Rename `IPriceOracle` to `IEulerPriceOracle`
/// - Remove `getQuotes` method

/// @title IPriceOracle
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Common PriceOracle interface.
interface IEulerPriceOracle {
    /// @notice Get the name of the oracle.
    /// @return The name of the oracle.
    function name() external view returns (string memory);

    /// @notice One-sided price: How much quote token you would get for inAmount of base token, assuming no price
    /// spread.
    /// @param inAmount The amount of `base` to convert.
    /// @param base The token that is being priced.
    /// @param quote The token that is the unit of account.
    /// @return outAmount The amount of `quote` that is equivalent to `inAmount` of `base`.
    function getQuote(uint256 inAmount, address base, address quote) external view returns (uint256 outAmount);
}
