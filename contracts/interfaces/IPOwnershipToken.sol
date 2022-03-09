// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import "./IPBaseToken.sol";

interface IPOwnershipToken is IPBaseToken {
    function initialize(address _YT) external;

    function burnByYT(address user, uint256 amount) external;

    function mintByYT(address user, uint256 amount) external;

    function LYT() external view returns (address);

    function YT() external view returns (address);
}
