// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PendleMerkleDepositor {
    using SafeERC20 for IERC20;

    event MerkleDeposit(bytes32 indexed campaignId, address indexed from, address indexed token, uint256 amount);

    address public constant NATIVE = address(0);
    address public immutable merkleDistributor;

    constructor(address _merkleDistributor) {
        merkleDistributor = _merkleDistributor;
    }

    /// @notice The `tokens` array must be sorted in strictly ascending order with no duplicates.
    function depositToMerkleCampaign(
        bytes32 campaignId,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external payable {
        uint256 length = tokens.length;

        require(length != 0, "PMD: empty array");
        require(length == amounts.length, "PMD: array length mismatch");

        uint256 amountNative;
        for (uint256 i = 0; i < length; ++i) {
            if (i != length - 1) require(_lt(tokens[i], tokens[i + 1]), "PMD: invalid tokens order");
            if (tokens[i] == NATIVE) amountNative = amounts[i];
        }

        require(amountNative == msg.value, "PMD: msg.value mismatch");

        for (uint256 i = 0; i < length; ++i) {
            if (amounts[i] != 0) {
                uint256 preBalance = _tokenBalance(tokens[i], merkleDistributor);
                _transferFrom(tokens[i], msg.sender, merkleDistributor, amounts[i]);
                uint256 amountDeposited = _tokenBalance(tokens[i], merkleDistributor) - preBalance;

                emit MerkleDeposit(campaignId, msg.sender, tokens[i], amountDeposited);
            }
        }
    }

    function _tokenBalance(address token, address account) internal view returns (uint256) {
        return token == NATIVE ? account.balance : IERC20(token).balanceOf(account);
    }

    function _transferFrom(address token, address from, address to, uint256 amount) internal {
        if (token == NATIVE) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "PMD: eth send failed");
        } else {
            IERC20(token).safeTransferFrom(from, to, amount);
        }
    }

    function _lt(address token0, address token1) internal pure returns (bool) {
        return token0 < token1;
    }
}
