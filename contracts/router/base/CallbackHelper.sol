// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPPrincipalToken.sol";
import "../../interfaces/IStandardizedYield.sol";

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

    function _encodeSwapExactSyForYt(
        address receiver,
        uint256 minYtOut,
        IPYieldToken YT
    ) internal pure returns (bytes memory res) {
        res = new bytes(128);
        uint256 actionType = uint256(ActionType.SwapExactSyForYt);

        assembly {
            mstore(add(res, 32), actionType)
            mstore(add(res, 64), receiver)
            mstore(add(res, 96), minYtOut)
            mstore(add(res, 128), YT)
        }
    }

    function _decodeSwapExactSyForYt(
        bytes calldata data
    ) internal pure returns (address receiver, uint256 minYtOut, IPYieldToken YT) {
        assembly {
            // first 32 bytes is ActionType
            receiver := calldataload(add(data.offset, 32))
            minYtOut := calldataload(add(data.offset, 64))
            YT := calldataload(add(data.offset, 96))
        }
    }

    /// ------------------------------------------------------------
    /// SwapSyForExactYt
    /// ------------------------------------------------------------

    function _encodeSwapSyForExactYt(
        address payer,
        address receiver,
        uint256 maxSyIn,
        IStandardizedYield SY,
        IPYieldToken YT
    ) internal pure returns (bytes memory res) {
        res = new bytes(192);
        uint256 actionType = uint256(ActionType.SwapSyForExactYt);

        assembly {
            mstore(add(res, 32), actionType)
            mstore(add(res, 64), payer)
            mstore(add(res, 96), receiver)
            mstore(add(res, 128), maxSyIn)
            mstore(add(res, 160), SY)
            mstore(add(res, 192), YT)
        }
    }

    function _decodeSwapSyForExactYt(
        bytes calldata data
    )
        internal
        pure
        returns (
            address payer,
            address receiver,
            uint256 maxSyIn,
            IStandardizedYield SY,
            IPYieldToken YT
        )
    {
        assembly {
            // first 32 bytes is ActionType
            payer := calldataload(add(data.offset, 32))
            receiver := calldataload(add(data.offset, 64))
            maxSyIn := calldataload(add(data.offset, 96))
            SY := calldataload(add(data.offset, 128))
            YT := calldataload(add(data.offset, 160))
        }
    }

    /// ------------------------------------------------------------
    /// SwapYtForSy (common encode & decode)
    /// ------------------------------------------------------------

    function _encodeSwapYtForSy(
        address receiver,
        uint256 minSyOut,
        IPYieldToken YT
    ) internal pure returns (bytes memory res) {
        res = new bytes(128);
        uint256 actionType = uint256(ActionType.SwapYtForSy);

        assembly {
            mstore(add(res, 32), actionType)
            mstore(add(res, 64), receiver)
            mstore(add(res, 96), minSyOut)
            mstore(add(res, 128), YT)
        }
    }

    function _decodeSwapYtForSy(
        bytes calldata data
    ) internal pure returns (address receiver, uint256 minSyOut, IPYieldToken YT) {
        assembly {
            // first 32 bytes is ActionType
            receiver := calldataload(add(data.offset, 32))
            minSyOut := calldataload(add(data.offset, 64))
            YT := calldataload(add(data.offset, 96))
        }
    }

    function _encodeSwapExactYtForPt(
        address receiver,
        uint256 exactYtIn,
        uint256 minPtOut,
        IPPrincipalToken PT,
        IPYieldToken YT
    ) internal pure returns (bytes memory res) {
        res = new bytes(192);
        uint256 actionType = uint256(ActionType.SwapExactYtForPt);

        assembly {
            mstore(add(res, 32), actionType)
            mstore(add(res, 64), receiver)
            mstore(add(res, 96), exactYtIn)
            mstore(add(res, 128), minPtOut)
            mstore(add(res, 160), PT)
            mstore(add(res, 192), YT)
        }
    }

    function _decodeSwapExactYtForPt(
        bytes calldata data
    )
        internal
        pure
        returns (
            address receiver,
            uint256 exactYtIn,
            uint256 minPtOut,
            IPPrincipalToken PT,
            IPYieldToken YT
        )
    {
        assembly {
            // first 32 bytes is ActionType
            receiver := calldataload(add(data.offset, 32))
            exactYtIn := calldataload(add(data.offset, 64))
            minPtOut := calldataload(add(data.offset, 96))
            PT := calldataload(add(data.offset, 128))
            YT := calldataload(add(data.offset, 160))
        }
    }

    function _encodeSwapExactPtForYt(
        address receiver,
        uint256 exactPtIn,
        uint256 minYtOut,
        IPYieldToken YT
    ) internal pure returns (bytes memory res) {
        res = new bytes(160);
        uint256 actionType = uint256(ActionType.SwapExactPtForYt);

        assembly {
            mstore(add(res, 32), actionType)
            mstore(add(res, 64), receiver)
            mstore(add(res, 96), exactPtIn)
            mstore(add(res, 128), minYtOut)
            mstore(add(res, 160), YT)
        }
    }

    function _decodeSwapExactPtForYt(
        bytes calldata data
    )
        internal
        pure
        returns (address receiver, uint256 exactPtIn, uint256 minYtOut, IPYieldToken YT)
    {
        assembly {
            // first 32 bytes is ActionType
            receiver := calldataload(add(data.offset, 32))
            exactPtIn := calldataload(add(data.offset, 64))
            minYtOut := calldataload(add(data.offset, 96))
            YT := calldataload(add(data.offset, 128))
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
