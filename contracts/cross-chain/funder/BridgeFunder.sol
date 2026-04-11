// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {BoringOwnableUpgradeableV2} from "../../core/libraries/BoringOwnableUpgradeableV2.sol";
import {TokenHelper} from "../../core/libraries/TokenHelper.sol";
import {BridgeData, IPBridgeFunder} from "../../interfaces/IPBridgeFunder.sol";
import {IPDepositBox} from "../../interfaces/IPDepositBox.sol";
import {IPDepositBoxFactory} from "../../interfaces/IPDepositBoxFactory.sol";

contract BridgeFunder is IPBridgeFunder, BoringOwnableUpgradeableV2, TokenHelper {
    using Address for address;
    using SafeERC20 for IERC20;

    IPDepositBoxFactory public immutable DEPOSIT_BOX_FACTORY;

    constructor(address depositBoxFactory_) {
        _disableInitializers();
        DEPOSIT_BOX_FACTORY = IPDepositBoxFactory(depositBoxFactory_);
    }

    function initialize(address _owner) external initializer {
        __BoringOwnableV2_init(_owner);
    }

    modifier onlyDepositBox() {
        IPDepositBox box = IPDepositBox(msg.sender);
        address owner = box.OWNER();
        uint32 boxId = box.BOX_ID();

        (address computedBox,,) = DEPOSIT_BOX_FACTORY.computeDepositBox(owner, boxId);
        require(computedBox == address(box), "BridgeFunder: caller is not deposit box");
        _;
    }

    function bridge(BridgeData memory $) external onlyDepositBox returns (bytes memory result) {
        require(
            $.bridgeToken != $.feeToken && $.bridgeToken != NATIVE && $.feeToken != NATIVE,
            "BridgeFunder: unsupported token"
        );

        _transferIn($.bridgeToken, msg.sender, $.bridgeAmount);
        _approveForExtRouter($.bridgeToken, $.bridgeExtRouter, $.bridgeAmount);
        _approveForExtRouter($.feeToken, $.bridgeExtRouter, $.feeAmount);

        result = $.bridgeExtRouter.functionCall($.bridgeCalldata);

        _approveForExtRouter($.bridgeToken, $.bridgeExtRouter, 0);
        _approveForExtRouter($.feeToken, $.bridgeExtRouter, 0);
    }

    function withdraw(address receiver, address token, uint256 amount) external onlyOwner {
        _transferOut(token, receiver, amount);
    }

    function _approveForExtRouter(address token, address extRouter, uint256 amount) internal {
        IERC20(token).forceApprove(extRouter, amount);
    }
}
