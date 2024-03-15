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

interface IPYieldContractFactory {
    event CreateYieldContract(address indexed SY, uint256 indexed expiry, address PT, address YT);

    event SetExpiryDivisor(uint256 newExpiryDivisor);

    event SetInterestFeeRate(uint256 newInterestFeeRate);

    event SetRewardFeeRate(uint256 newRewardFeeRate);

    event SetTreasury(address indexed treasury);

    function getPT(address SY, uint256 expiry) external view returns (address);

    function getYT(address SY, uint256 expiry) external view returns (address);

    function expiryDivisor() external view returns (uint96);

    function interestFeeRate() external view returns (uint128);

    function rewardFeeRate() external view returns (uint128);

    function treasury() external view returns (address);

    function isPT(address) external view returns (bool);

    function isYT(address) external view returns (bool);

    function createYieldContract(
        address SY,
        uint32 expiry,
        bool doCacheIndexSameBlock
    ) external returns (address PT, address YT);
}
