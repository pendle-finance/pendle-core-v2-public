// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {TokenHelper} from "../../core/libraries/TokenHelper.sol";
import {ApprovedCall, IPLoopPositionBox} from "../../interfaces/IPLoopPositionBox.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract LoopPositionBox is IPLoopPositionBox, TokenHelper, Initializable {
    using Address for address;
    using SafeERC20 for IERC20;

    address public immutable MANAGER;

    /// @dev `OWNER` / `BOX_ID` / `SPOKE_MONEY_MARKET` are written once in `initialize` and never
    /// mutated again. Named in ALL-CAPS to match `MANAGER` and signal "set-once" intent at the
    /// callsite, even though they live in storage (BeaconProxy delegatecall rules out true
    /// `immutable`). Renaming would break `IPLoopPositionBox` ABI consumers.
    address public OWNER;
    bytes32 public BOX_ID;
    address public SPOKE_MONEY_MARKET;

    constructor(address _manager) {
        MANAGER = _manager;
    }

    modifier onlyManager() {
        require(msg.sender == MANAGER, "LoopPositionBox: caller is not manager");
        _;
    }

    function initialize(
        address _owner,
        bytes32 _boxId,
        address _spokeMoneyMarket,
        address _ptToApprove,
        address _debtTokenToApprove
    ) external initializer {
        OWNER = _owner;
        BOX_ID = _boxId;
        SPOKE_MONEY_MARKET = _spokeMoneyMarket;

        if (_spokeMoneyMarket != address(0)) {
            _safeApproveInf(_ptToApprove, _spokeMoneyMarket);
            _safeApproveInf(_debtTokenToApprove, _spokeMoneyMarket);
        }
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

        // Back out the native the manager just sent in (call.amount if NATIVE, plus the msg.value fee)
        // so the post-call diff refunds only router-returned surplus, not the box's pre-existing native.
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
        if (token == NATIVE || extRouter == SPOKE_MONEY_MARKET) return;
        IERC20(token).forceApprove(extRouter, amount);
    }

    receive() external payable {}
}
