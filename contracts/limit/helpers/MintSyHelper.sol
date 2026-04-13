// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../interfaces/IPLimitRouter.sol";
import "../../interfaces/IPAllActionTypeV3.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";

abstract contract MintSyHelper is EIP712Upgradeable {
    // forgefmt: disable-next-item
    bytes32 internal constant SWAP_DATA_TYPEHASH = keccak256(
        "SwapData("
            "uint8 swapType,"
            "address extRouter,"
            "bytes extCalldata,"
            "bool needScale"
        ")"
    );

    // forgefmt: disable-next-item
    bytes32 internal constant TOKEN_INPUT_TYPEHASH = keccak256(
        "TokenInput("
            "address tokenIn,"
            "uint256 netTokenIn,"
            "address tokenMintSy,"
            "address pendleSwap,"
            "SwapData swapData"
        ")"
        "SwapData("
            "uint8 swapType,"
            "address extRouter,"
            "bytes extCalldata,"
            "bool needScale"
        ")"
    );

    // forgefmt: disable-next-item
    bytes32 internal constant MINT_SY_PAYLOAD_TYPEHASH = keccak256(
        "MintSyPayload("
            "TokenInput[] inps,"
            "uint256[] minSyOuts,"
            "uint256 expiry,"
            "bytes32 fillParamsHash"
        ")"
        "SwapData("
            "uint8 swapType,"
            "address extRouter,"
            "bytes extCalldata,"
            "bool needScale"
        ")"
        "TokenInput("
            "address tokenIn,"
            "uint256 netTokenIn,"
            "address tokenMintSy,"
            "address pendleSwap,"
            "SwapData swapData"
        ")"
    );

    function _verifyMintSyData(MintSyData memory mintSyData, bytes32 fillParamsHash, address signer1, address signer2)
        internal
        view
    {
        require(block.timestamp < mintSyData.expiry, "LOP: mintSy expired");
        require(mintSyData.fillParamsHash == fillParamsHash, "LOP: mintSy params mismatch");
        require(mintSyData.inps.length == mintSyData.minSyOuts.length, "LOP: length mismatch");

        bytes32 digest =
            hashMintSyPayload(mintSyData.inps, mintSyData.minSyOuts, mintSyData.expiry, mintSyData.fillParamsHash);

        require(SignatureChecker.isValidSignatureNow(signer1, digest, mintSyData.sig1), "LOP: bad mintSy sig1");
        require(SignatureChecker.isValidSignatureNow(signer2, digest, mintSyData.sig2), "LOP: bad mintSy sig2");
    }

    function _hashSwapData(SwapData memory d) internal pure returns (bytes32) {
        return keccak256(abi.encode(SWAP_DATA_TYPEHASH, d.swapType, d.extRouter, keccak256(d.extCalldata), d.needScale));
    }

    function _hashTokenInput(TokenInput memory inp) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                TOKEN_INPUT_TYPEHASH,
                inp.tokenIn,
                inp.netTokenIn,
                inp.tokenMintSy,
                inp.pendleSwap,
                _hashSwapData(inp.swapData)
            )
        );
    }

    function hashMintSyPayload(
        TokenInput[] memory inps,
        uint256[] memory minSyOuts,
        uint256 expiry,
        bytes32 fillParamsHash
    ) public view returns (bytes32) {
        bytes32[] memory inpHashes = new bytes32[](inps.length);
        for (uint256 i = 0; i < inps.length; i++) {
            inpHashes[i] = _hashTokenInput(inps[i]);
        }
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    MINT_SY_PAYLOAD_TYPEHASH,
                    keccak256(abi.encodePacked(inpHashes)),
                    keccak256(abi.encodePacked(minSyOuts)),
                    expiry,
                    fillParamsHash
                )
            )
        );
    }
}
