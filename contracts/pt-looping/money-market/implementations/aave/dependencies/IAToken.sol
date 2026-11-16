// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IAToken is IERC20 {
    function scaledTotalSupply() external view returns (uint256);
}
