// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "./IPBaseToken.sol";

interface IPPrincipalToken is IPBaseToken {
    function initialize(address _YT) external;

    function burnByYT(address user, uint256 amount) external;

    function mintByYT(address user, uint256 amount) external;

    function SCY() external view returns (address);

    function YT() external view returns (address);
}
