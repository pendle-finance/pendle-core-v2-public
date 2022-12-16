pragma solidity 0.8.17;

library BasePoolUserData {
    uint8 public constant RECOVERY_MODE_EXIT_KIND = 255;

    function isRecoveryModeExitKind(bytes memory self) internal pure returns (bool) {
        return self.length > 0 && abi.decode(self, (uint8)) == RECOVERY_MODE_EXIT_KIND;
    }

    function recoveryModeExit(bytes memory self) internal pure returns (uint256 bptAmountIn) {
        (, bptAmountIn) = abi.decode(self, (uint8, uint256));
    }
}