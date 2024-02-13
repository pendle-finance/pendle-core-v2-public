pragma solidity ^0.8.0;

interface IPActionVePendleStaticLe1 {
    function increaseLockPositionStatic(
        address user,
        uint128 additionalAmountToLock,
        uint128 newExpiry
    ) external view returns (uint128 newVeBalance);
}
