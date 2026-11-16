// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
import {IOAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {
    IERC20MetadataUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

interface IPBridgedPrincipalToken is IOFT, IOAppCore, IOAppOptionsType3, IERC20MetadataUpgradeable {
    function expiry() external view returns (uint256);
}
