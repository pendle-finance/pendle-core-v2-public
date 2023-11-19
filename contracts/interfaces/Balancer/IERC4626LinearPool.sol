// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IERC4626LinearPool {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event PausedStateChanged(bool paused);
    event RecoveryModeStateChanged(bool enabled);
    event SwapFeePercentageChanged(uint256 swapFeePercentage);
    event TargetsSet(address indexed token, uint256 lowerTarget, uint256 upperTarget);
    event Transfer(address indexed from, address indexed to, uint256 value);

    struct SwapRequest {
        uint8 kind;
        address tokenIn;
        address tokenOut;
        uint256 amount;
        bytes32 poolId;
        uint256 lastChangeBlock;
        address from;
        address to;
        bytes userData;
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 amount) external returns (bool);

    function disableRecoveryMode() external;

    function enableRecoveryMode() external;

    function getActionId(bytes4 selector) external view returns (bytes32);

    function getAuthorizer() external view returns (address);

    function getBptIndex() external pure returns (uint256);

    function getDomainSeparator() external view returns (bytes32);

    function getMainIndex() external view returns (uint256);

    function getMainToken() external view returns (address);

    function getNextNonce(address account) external view returns (uint256);

    function getOwner() external view returns (address);

    function getPausedState()
        external
        view
        returns (bool paused, uint256 pauseWindowEndTime, uint256 bufferPeriodEndTime);

    function getPoolId() external view returns (bytes32);

    function getProtocolFeesCollector() external view returns (address);

    function getRate() external view returns (uint256);

    function getScalingFactors() external view returns (uint256[] memory);

    function getSwapFeePercentage() external view returns (uint256);

    function getTargets() external view returns (uint256 lowerTarget, uint256 upperTarget);

    function getVault() external view returns (address);

    function getVirtualSupply() external view returns (uint256);

    function getWrappedIndex() external view returns (uint256);

    function getWrappedToken() external view returns (address);

    function getWrappedTokenRate() external view returns (uint256);

    function inRecoveryMode() external view returns (bool);

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    function initialize() external;

    function name() external view returns (string memory);

    function nonces(address owner) external view returns (uint256);

    function onExitPool(
        bytes32 poolId,
        address sender,
        address,
        uint256[] memory balances,
        uint256,
        uint256,
        bytes memory userData
    ) external returns (uint256[] memory amountsOut, uint256[] memory dueProtocolFees);

    function onJoinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256,
        uint256,
        bytes memory userData
    ) external returns (uint256[] memory amountsIn, uint256[] memory dueProtocolFees);

    function onSwap(
        SwapRequest memory request,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 indexOut
    ) external returns (uint256);

    function onSwap(
        SwapRequest memory request,
        uint256 balanceTokenIn,
        uint256 balanceTokenOut
    ) external returns (uint256);

    function pause() external;

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function queryExit(
        bytes32,
        address sender,
        address,
        uint256[] memory balances,
        uint256,
        uint256,
        bytes memory userData
    ) external returns (uint256 bptIn, uint256[] memory amountsOut);

    function queryJoin(
        bytes32,
        address sender,
        address,
        uint256[] memory balances,
        uint256,
        uint256,
        bytes memory userData
    ) external returns (uint256 bptOut, uint256[] memory amountsIn);

    function setSwapFeePercentage(uint256 swapFeePercentage) external;

    function setTargets(uint256 newLowerTarget, uint256 newUpperTarget) external;

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function unpause() external;

    function version() external view returns (string memory);
}
