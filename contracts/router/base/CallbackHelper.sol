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
        returns (bytes memory res)
    {
        res = new bytes(96);
        uint256 actionType = uint256(ActionType.SwapExactSyForYt);

        assembly {
            mstore(add(res, 32), actionType)
            mstore(add(res, 64), receiver)
            mstore(add(res, 96), minYtOut)
        }
    }

    function _decodeSwapExactSyForYt(bytes calldata data)
        internal
        pure
        returns (address receiver, uint256 minYtOut)
    {
        assembly {
            // first 32 bytes is ActionType
            receiver := calldataload(add(data.offset, 32))
            minYtOut := calldataload(add(data.offset, 64))
        }
    }

    /// ------------------------------------------------------------
    /// SwapSyForExactYt
    /// ------------------------------------------------------------

    function _encodeSwapSyForExactYt(
        address payer,
        address receiver,
        uint256 maxSyIn
    ) internal pure returns (bytes memory res) {
        res = new bytes(128);
        uint256 actionType = uint256(ActionType.SwapSyForExactYt);

        assembly {
            mstore(add(res, 32), actionType)
            mstore(add(res, 64), payer)
            mstore(add(res, 96), receiver)
            mstore(add(res, 128), maxSyIn)
        }
    }

    function _decodeSwapSyForExactYt(bytes calldata data)
        internal
        pure
        returns (
            address payer,
            address receiver,
            uint256 maxSyIn
        )
    {
        assembly {
            // first 32 bytes is ActionType
            payer := calldataload(add(data.offset, 32))
            receiver := calldataload(add(data.offset, 64))
            maxSyIn := calldataload(add(data.offset, 96))
        }
    }

    /// ------------------------------------------------------------
    /// SwapYtForSy (common encode & decode)
    /// ------------------------------------------------------------

    function _encodeSwapYtForSy(address receiver, uint256 minSyOut)
        internal
        pure
        returns (bytes memory res)
    {
        res = new bytes(96);
        uint256 actionType = uint256(ActionType.SwapYtForSy);

        assembly {
            mstore(add(res, 32), actionType)
            mstore(add(res, 64), receiver)
            mstore(add(res, 96), minSyOut)
        }
    }

    function _decodeSwapYtForSy(bytes calldata data)
        internal
        pure
        returns (address receiver, uint256 minSyOut)
    {
        assembly {
            // first 32 bytes is ActionType
            receiver := calldataload(add(data.offset, 32))
            minSyOut := calldataload(add(data.offset, 64))
        }
    }

    function _encodeSwapExactYtForPt(
        address receiver,
        uint256 exactYtIn,
        uint256 minPtOut
    ) internal pure returns (bytes memory res) {
        res = new bytes(128);
        uint256 actionType = uint256(ActionType.SwapExactYtForPt);

        assembly {
            mstore(add(res, 32), actionType)
            mstore(add(res, 64), receiver)
            mstore(add(res, 96), exactYtIn)
            mstore(add(res, 128), minPtOut)
        }
    }

    function _decodeSwapExactYtForPt(bytes calldata data)
        internal
        pure
        returns (
            address receiver,
            uint256 exactYtIn,
            uint256 minPtOut
        )
    {
        assembly {
            // first 32 bytes is ActionType
            receiver := calldataload(add(data.offset, 32))
            exactYtIn := calldataload(add(data.offset, 64))
            minPtOut := calldataload(add(data.offset, 96))
        }
    }

    function _encodeSwapExactPtForYt(
        address receiver,
        uint256 exactPtIn,
        uint256 minYtOut
    ) internal pure returns (bytes memory res) {
        res = new bytes(128);
        uint256 actionType = uint256(ActionType.SwapExactPtForYt);

        assembly {
            mstore(add(res, 32), actionType)
            mstore(add(res, 64), receiver)
            mstore(add(res, 96), exactPtIn)
            mstore(add(res, 128), minYtOut)
        }
    }

    function _decodeSwapExactPtForYt(bytes calldata data)
        internal
        pure
        returns (
            address receiver,
            uint256 exactPtIn,
            uint256 minYtOut
        )
    {
        assembly {
            // first 32 bytes is ActionType
            receiver := calldataload(add(data.offset, 32))
            exactPtIn := calldataload(add(data.offset, 64))
            minYtOut := calldataload(add(data.offset, 96))
        }
    }

    /// ------------------------------------------------------------
    /// Misc functions
    /// ------------------------------------------------------------
    function _getActionType(bytes calldata data) internal pure returns (ActionType actionType) {
        assembly {
            actionType := calldataload(data.offset)
        }
    }
}
