// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {TokenHelper} from "../../core/libraries/TokenHelper.sol";
import {ApprovedCall, IPDepositBox} from "../../interfaces/IPDepositBox.sol";

contract DepositBox is IPDepositBox, TokenHelper, Initializable {
    using Address for address;
    using SafeERC20 for IERC20;

    address public immutable MANAGER;
    address public OWNER;
    uint32 public BOX_ID;

    constructor(address manager_) {
        _disableInitializers();
        MANAGER = manager_;
    }

    modifier onlyManager() {
        require(msg.sender == MANAGER, "DepositBox: caller is not manager");
        _;
    }

    function initialize(address owner_, uint32 boxId_) external initializer {
        OWNER = owner_;
        BOX_ID = boxId_;
    }

    function withdrawTo(address to, address token, uint256 amount) external onlyManager {
        _transferOut(token, to, amount);
    }

    function approveAndCall(ApprovedCall memory call, address nativeRefund)
        external
        payable
        onlyManager
        returns (bytes memory result)
    {
        uint256 nativeAmount = call.token == NATIVE ? call.amount : 0;
        uint256 nativeFee = msg.value;

        uint256 initialNativeBalance = _selfBalance(NATIVE) - nativeAmount - nativeFee;

        _approveForExtRouter(call.token, call.approveTo, call.amount);
        result = call.callTo.functionCallWithValue(call.data, nativeAmount + nativeFee);
        _approveForExtRouter(call.token, call.approveTo, 0);

        uint256 finalNativeBalance = _selfBalance(NATIVE);

        if (finalNativeBalance > initialNativeBalance) {
            _transferOut(NATIVE, nativeRefund, finalNativeBalance - initialNativeBalance);
        }
    }

    function _approveForExtRouter(address token, address extRouter, uint256 amount) internal {
        if (token == NATIVE) return;
        IERC20(token).forceApprove(extRouter, amount);
    }

    receive() external payable {}
}
