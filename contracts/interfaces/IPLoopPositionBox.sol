// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @dev `tokens` are ERC20 only; native value goes in `nativeAmount`. The other fields mirror `BoxApprovedCall`.
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

    /// @dev Beacon of the spoke money market adapter.
    address spokeMMBeacon;
    /// @dev Adapter-specific market id. See each `*MMPayloadLib`.
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

    function MORPHO() external view returns (address);

    /// @notice Manager only. Flash-borrows `assets` of `token` from Morpho and calls the manager with `data`
    ///         inside the loan. Morpho pulls the loan back after.
    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    /// @notice Morpho Blue flash-loan callback. Relays `data` to the manager.
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}
