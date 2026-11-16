// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {TokenHelper} from "../../core/libraries/TokenHelper.sol";
import {BoxCall, IPLoopPositionBox} from "../../interfaces/IPLoopPositionBox.sol";
import {IMorpho} from "../money-market/implementations/morpho/dependencies/IMorpho.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract LoopPositionBox is IPLoopPositionBox, TokenHelper, Initializable {
    using Address for address;
    using SafeERC20 for IERC20;

    address public immutable MANAGER;

    /// @dev Morpho Blue singleton, the flash lender. Zero on a chain without Morpho.
    address public immutable MORPHO;

    /// @dev Set once in `initialize`. In storage, as the box is a beacon proxy; ALL-CAPS marks them set-once.
    address public OWNER;
    bytes32 public BOX_ID;
    address public SPOKE_MONEY_MARKET;

    constructor(address _manager, address _morpho) {
        MANAGER = _manager;
        MORPHO = _morpho;
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

    function approveAndCall(BoxCall memory call, address nativeRefund)
        external
        payable
        onlyManager
        returns (bytes memory result)
    {
        require(call.tokens.length == call.amounts.length, "LoopPositionBox: tokens/amounts length mismatch");
        // The reset to zero below would wipe the spoke MM's infinite approval from `initialize`.
        require(
            SPOKE_MONEY_MARKET == address(0) || call.approve != SPOKE_MONEY_MARKET,
            "LoopPositionBox: approve cannot be spokeMM"
        );

        uint256 nativeFee = msg.value;

        // The balance the box ends with if the router keeps all native value sent. The rest goes to `nativeRefund`.
        uint256 initialNativeBalance = _selfBalance(NATIVE) - call.nativeAmount - nativeFee;

        for (uint256 i = 0; i < call.tokens.length; ++i) {
            IERC20(call.tokens[i]).forceApprove(call.approve, call.amounts[i]);
        }
        result = call.extRouter.functionCallWithValue(call.callData, call.nativeAmount + nativeFee);
        for (uint256 i = 0; i < call.tokens.length; ++i) {
            IERC20(call.tokens[i]).forceApprove(call.approve, 0);
        }

        uint256 finalNativeBalance = _selfBalance(NATIVE);

        if (finalNativeBalance > initialNativeBalance) {
            _transferOut(NATIVE, nativeRefund, finalNativeBalance - initialNativeBalance);
        }
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external onlyManager {
        IERC20(token).forceApprove(MORPHO, assets);
        IMorpho(MORPHO).flashLoan(token, assets, data);
    }

    /// @dev Morpho calls back only the borrower, and only a manager call makes this box borrow. The manager
    /// decides what `data` may run.
    function onMorphoFlashLoan(uint256, bytes calldata data) external {
        require(msg.sender == MORPHO, "LoopPositionBox: unauthorized flash callback");
        MANAGER.functionCall(data);
    }

    receive() external payable {}
}
