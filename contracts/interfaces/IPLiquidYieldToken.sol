// SPDX-License-Identifier: GPL-3.0-or-later
/*
 * MIT License
 * ===========
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 */

pragma solidity ^0.8.0;
import "openzeppelin-solidity/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IPLiquidYieldToken is IERC20Metadata {
    struct GlobalReward {
        uint256 index;
        uint256 lastBalance;
    }

    struct UserReward {
        uint256 lastIndex;
        uint256 accuredReward;
    }

    function mint(address recipient, uint256 amountUnderlyingIn)
        external
        returns (uint256 amountLytOut);

    function mintFromRawToken(
        address recipient,
        address rawToken,
        uint256 amountRawIn,
        uint256 minAmountLytOut,
        bytes calldata data
    ) external returns (uint256 amountLytOut);

    function burn(address recipient, uint256 amountLytIn)
        external
        returns (uint256 amountUnderlyingOut);

    function burnToRawToken(
        address recipient,
        address rawToken,
        uint256 amountLytIn,
        uint256 minAmountRawOut,
        bytes calldata data
    ) external returns (uint256 amountRawOut);

    function redeemReward() external returns (uint256[] memory outAmounts);

    function exchangeRateCurrent() external returns (uint256);

    function underlyingDecimals() external view returns (uint8);

    function rewardTokens(uint256) external view returns (address);

    function getRewardTokens() external view returns (address[] memory res);
}
