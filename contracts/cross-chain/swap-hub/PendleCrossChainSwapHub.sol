// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {ApprovedCall, IPDepositBox} from "../../interfaces/IPDepositBox.sol";
import {SwapHubBase} from "./SwapHubBase.sol";

contract PendleCrossChainSwapHub is SwapHubBase {
    constructor(address treasury_, address depositBoxFactory_) SwapHubBase(treasury_, depositBoxFactory_) {
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        __EIP712_init("Pendle Cross Chain Swap Hub", "1");
        __BoringOwnableV2_init(_owner);
    }

    function withdrawToken(WithdrawTokenMessage memory ms, bytes memory sig) external onlyExecutor {
        IPDepositBox box = _checkBoxPermit(ms.permit, hashTypedData(ms), sig);
        _payTreasury(box, ms.token, ms.amountFee);
        _withdrawToken(ms, box);

        emit WithdrawToken(
            ms.permit.owner,
            ms.permit.boxId,
            ms.permit.requestId,
            ms.permit.nonce,
            ms.token,
            ms.amountWithdraw,
            ms.amountFee
        );
    }

    function bridgeToken(BridgeTokenMessage memory ms, bytes memory sig) external payable onlyExecutor {
        IPDepositBox box = _checkBoxPermit(ms.permit, hashTypedData(ms), sig);
        _payTreasury(box, ms.token, ms.amountFee);
        _bridgeToken(ms, box, msg.value);

        emit BridgeToken(
            ms.permit.owner,
            ms.permit.boxId,
            ms.permit.requestId,
            ms.permit.nonce,
            ms.bridgeExtRouter,
            ms.token,
            ms.amountBridge,
            ms.amountFee
        );
    }

    function swapToken(SwapTokenMessage memory ms, bytes memory sig) external onlyExecutor {
        IPDepositBox box = _checkBoxPermit(ms.permit, hashTypedData(ms), sig);
        // swapToken does not pay treasury

        uint256 netTokenReceived = _swapToken(ms, box);
        require(netTokenReceived >= ms.minReceived, InsufficientTokenReceived());

        emit SwapToken(
            ms.permit.owner,
            ms.permit.boxId,
            ms.permit.requestId,
            ms.permit.nonce,
            ms.tokenSpent,
            ms.amountSpent,
            ms.tokenReceived,
            netTokenReceived
        );
    }

    function _payTreasury(IPDepositBox box, address token, uint256 amount) internal {
        box.withdrawTo(TREASURY, token, amount);
    }

    function _withdrawToken(WithdrawTokenMessage memory ms, IPDepositBox box) internal {
        box.withdrawTo(ms.permit.owner, ms.token, ms.amountWithdraw);
    }

    function _bridgeToken(BridgeTokenMessage memory ms, IPDepositBox box, uint256 nativeFee) internal {
        ApprovedCall memory call = ApprovedCall({
            token: ms.token,
            amount: ms.amountBridge,
            approveTo: ms.bridgeApprove,
            callTo: ms.bridgeExtRouter,
            data: ms.bridgeCalldata
        });
        box.approveAndCall{value: nativeFee}(call, msg.sender);
    }

    function _swapToken(SwapTokenMessage memory ms, IPDepositBox box) internal returns (uint256 rawTokenReceived) {
        ApprovedCall memory call = ApprovedCall({
            token: ms.tokenSpent,
            amount: ms.amountSpent,
            approveTo: ms.swapApprove,
            callTo: ms.swapExtRouter,
            data: ms.swapCalldata
        });

        uint256 preBalance = _balanceOf(address(box), ms.tokenReceived);
        box.approveAndCall(call, address(box));
        rawTokenReceived = _balanceOf(address(box), ms.tokenReceived) - preBalance;
    }
}
