// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "openzeppelin-solidity/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IPBaseToken is IERC20Metadata {
    function expiry() external view returns (uint256);

    function isExpired() external view returns (bool);
}
