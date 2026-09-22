// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMoneyMarket} from "./IMoneyMarket.sol";

/// @dev `tokens` are ERC20 only; native value goes in `nativeAmount`.
/// `approve` / `extRouter` / `callData` mirror `IPPTLooperEIP712Types.BoxApprovedCall`.
struct BoxCall {
    address[] tokens;
    uint256[] amounts;
    uint256 nativeAmount;
    address approve;
    address extRouter;
    bytes callData;
}

struct BoxData {
    uint32 hubChainId;
    uint32 spokeChainId;

    address hubPt;
    address hubDebtToken;
    address spokePt;
    address spokeDebtToken;

    address spokeMMBeacon;
    // money market's specific payload
    bytes32 mmPayload;
}

interface IPLoopPositionBox {
    function MANAGER() external view returns (address);
    function OWNER() external view returns (address);
    function BOX_ID() external view returns (bytes32);
    function SPOKE_MONEY_MARKET() external view returns (address);

    function initialize(
        address owner,
        bytes32 boxId,
        address spokeMoneyMarket,
        address ptToApprove,
        address debtTokenToApprove
    ) external;

    function withdrawTo(address to, address token, uint256 amount) external;

    function approveAndCall(BoxCall memory call, address nativeRefund) external payable returns (bytes memory);
}
