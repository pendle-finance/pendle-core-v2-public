// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

/**
 * @notice Simple interface to retrieve the version of a deployed contract.
 */
interface IVersion {
    /**
     * @dev Returns a JSON representation of the contract version containing name, version number and task ID.
     */
    function version() external view returns (string memory);
}
