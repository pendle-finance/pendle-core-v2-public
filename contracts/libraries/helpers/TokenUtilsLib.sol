// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";

library TokenUtils {
    using SafeERC20 for IERC20;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        token.safeTransfer(to, value);
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        token.safeTransferFrom(from, to, value);
    }

    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        token.safeApprove(spender, 0);
        token.safeApprove(spender, value);
    }

    function infinityApprove(IERC20 token, address spender) internal {
        if (token.allowance(address(this), spender) <= type(uint256).max / 2) {
            safeApprove(token, spender, type(uint256).max);
        }
    }

    function requireERC20(address tokenAddr) internal view {
        require(IERC20(tokenAddr).totalSupply() > 0, "INVALID_ERC20");
    }

    function requireERC20(IERC20 token) internal view {
        require(token.totalSupply() > 0, "INVALID_ERC20");
    }
}
