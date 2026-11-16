// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPTrustedRedeemer {
    /// @notice The account the in-flight burn is metered against
    function burnAccount() external view returns (address);
}
