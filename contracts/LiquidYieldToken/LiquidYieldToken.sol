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
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

abstract contract LiquidYieldToken is ERC20 {
    uint8 private immutable _lytdecimals;
    uint8 private immutable _assetDecimals;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __lytdecimals,
        uint8 __assetDecimals
    ) ERC20(_name, _symbol) {
        _lytdecimals = __lytdecimals;
        _assetDecimals = __assetDecimals;
    }

    function depositBaseToken(
        address recipient,
        address baseTokenIn,
        uint256 amountBaseIn,
        uint256 minAmountLytOut
    ) public virtual returns (uint256 amountLytOut);

    function redeemToBaseToken(
        address recipient,
        uint256 amountLytRedeem,
        address baseTokenOut,
        uint256 minAmountBaseOut
    ) public virtual returns (uint256 amountBaseOut);

    function assetBalanceOf(address account) public virtual returns (uint256);

    function lytIndexCurrent() public virtual returns (uint256);

    function updateUserReward(address user) public virtual;

    function updateGlobalReward() public virtual;

    function redeemReward() public virtual returns (uint256[] memory outAmounts);

    function lytIndexStored() public view virtual returns (uint256);

    function getBaseTokens() public view virtual returns (address[] memory res);

    function getRewardTokens() public view virtual returns (address[] memory res);

    function decimals() public view virtual override returns (uint8) {
        return _lytdecimals;
    }

    function assetDecimals() public view virtual returns (uint8) {
        return _assetDecimals;
    }

    // ERC20-functions

    // function _beforeTokenTransfer(
    //     address from,
    //     address to,
    //     uint256 amount
    // ) internal virtual {}

    // function _afterTokenTransfer(
    //     address from,
    //     address to,
    //     uint256 amount
    // ) internal virtual {}
}
