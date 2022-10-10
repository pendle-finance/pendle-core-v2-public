// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

abstract contract CallbackHelper {
    enum ActionType {
        SwapSyForExactYt,
        SwapExactSyForYt,
        SwapYtForSy,
        SwapExactYtForPt,
        SwapExactPtForYt
    }

    /// ------------------------------------------------------------
    /// SwapExactSyForYt
    /// ------------------------------------------------------------

    function _encodeSwapExactSyForYt(address receiver, uint256 minYtOut)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(ActionType.SwapExactSyForYt, receiver, minYtOut);
    }

    function _decodeSwapExactSyForYt(bytes memory data)
        internal
        pure
        returns (address receiver, uint256 minYtOut)
    {
        (, receiver, minYtOut) = abi.decode(data, (ActionType, address, uint256));
    }

    /// ------------------------------------------------------------
    /// SwapSyForExactYt
    /// ------------------------------------------------------------

    function _encodeSwapSyForExactYt(
        address payer,
        address receiver,
        uint256 maxSyIn
    ) internal pure returns (bytes memory) {
        return abi.encode(ActionType.SwapSyForExactYt, payer, receiver, maxSyIn);
    }

    function _decodeSwapSyForExactYt(bytes memory data)
        internal
        pure
        returns (
            address payer,
            address receiver,
            uint256 maxSyIn
        )
    {
        (, payer, receiver, maxSyIn) = abi.decode(data, (ActionType, address, address, uint256));
    }

    /// ------------------------------------------------------------
    /// SwapYtForSy (common encode & decode)
    /// ------------------------------------------------------------

    function _encodeSwapYtForSy(address receiver, uint256 minSyOut)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(ActionType.SwapYtForSy, receiver, minSyOut);
    }

    function _decodeSwapYtForSy(bytes memory data)
        internal
        pure
        returns (address receiver, uint256 minSyOut)
    {
        (, receiver, minSyOut) = abi.decode(data, (ActionType, address, uint256));
    }

    function _encodeSwapExactYtForPt(
        address receiver,
        uint256 exactYtIn,
        uint256 minPtOut
    ) internal pure returns (bytes memory) {
        return abi.encode(ActionType.SwapExactYtForPt, receiver, exactYtIn, minPtOut);
    }

    function _decodeSwapExactYtForPt(bytes memory data)
        internal
        pure
        returns (
            address receiver,
            uint256 exactYtIn,
            uint256 minPtOut
        )
    {
        (, receiver, exactYtIn, minPtOut) = abi.decode(
            data,
            (ActionType, address, uint256, uint256)
        );
    }

    function _encodeSwapExactPtForYt(
        address receiver,
        uint256 exactPtIn,
        uint256 minYtOut
    ) internal pure returns (bytes memory) {
        return abi.encode(ActionType.SwapExactPtForYt, receiver, exactPtIn, minYtOut);
    }

    function _decodeSwapExactPtForYt(bytes memory data)
        internal
        pure
        returns (
            address receiver,
            uint256 exactPtIn,
            uint256 minYtOut
        )
    {
        (, receiver, exactPtIn, minYtOut) = abi.decode(
            data,
            (ActionType, address, uint256, uint256)
        );
    }

    /// ------------------------------------------------------------
    /// Misc functions
    /// ------------------------------------------------------------
    function _getActionType(bytes memory data) internal pure returns (ActionType actionType) {
        actionType = abi.decode(data, (ActionType));
    }
}
