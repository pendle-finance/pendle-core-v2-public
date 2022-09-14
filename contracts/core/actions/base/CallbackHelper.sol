// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

abstract contract CallbackHelper {
    enum ActionType {
        SwapScyForExactYt,
        SwapExactScyForYt,
        SwapYtForScy,
        SwapExactYtForPt,
        SwapExactPtForYt
    }

    /// ------------------------------------------------------------
    /// SwapExactScyForYt
    /// ------------------------------------------------------------

    function _encodeSwapExactScyForYt(address receiver, uint256 minYtOut)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(ActionType.SwapExactScyForYt, receiver, minYtOut);
    }

    function _decodeSwapExactScyForYt(bytes memory data)
        internal
        pure
        returns (address receiver, uint256 minYtOut)
    {
        (, receiver, minYtOut) = abi.decode(data, (ActionType, address, uint256));
    }

    /// ------------------------------------------------------------
    /// SwapScyForExactYt
    /// ------------------------------------------------------------

    function _encodeSwapScyForExactYt(
        address payer,
        address receiver,
        uint256 maxScyIn
    ) internal pure returns (bytes memory) {
        return abi.encode(ActionType.SwapScyForExactYt, payer, receiver, maxScyIn);
    }

    function _decodeSwapScyForExactYt(bytes memory data)
        internal
        pure
        returns (
            address payer,
            address receiver,
            uint256 maxScyIn
        )
    {
        (, payer, receiver, maxScyIn) = abi.decode(data, (ActionType, address, address, uint256));
    }

    /// ------------------------------------------------------------
    /// SwapYtForScy (common encode & decode)
    /// ------------------------------------------------------------

    function _encodeSwapYtForScy(address receiver, uint256 minScyOut)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(ActionType.SwapYtForScy, receiver, minScyOut);
    }

    function _decodeSwapYtForScy(bytes memory data)
        internal
        pure
        returns (address receiver, uint256 minScyOut)
    {
        (, receiver, minScyOut) = abi.decode(data, (ActionType, address, uint256));
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
