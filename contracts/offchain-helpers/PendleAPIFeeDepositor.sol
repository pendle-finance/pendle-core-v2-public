// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../core/libraries/TokenHelper.sol";

contract PendleAPIFeeDepositor is TokenHelper {
    event DepositReceived(address indexed account, address token, uint256 amount);

    address public immutable treasury;

    mapping(address token => mapping(address account => uint256 amount)) public totalDeposit;

    constructor(address _treasury) {
        treasury = _treasury;
    }

    function deposit(address token, uint256 amount) external payable {
        uint256 amountNative = token == NATIVE ? amount : 0;

        require(amount != 0, "zero amount");
        require(amountNative == msg.value, "msg.value mismatch");

        totalDeposit[token][msg.sender] += amount;

        if (amountNative != 0) {
            _transferOut(token, treasury, amountNative);
        } else {
            _transferFrom(IERC20(token), msg.sender, treasury, amount);
        }

        emit DepositReceived(msg.sender, token, amount);
    }
}
