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

pragma solidity 0.8.17;

interface IPYieldContractFactory {
    /// @dev emitted when a yield contract is created using (`SY`) and (`expiry`)
    event CreateYieldContract(address indexed SY, address PT, address YT, uint256 expiry);

    /// @dev emitted when a new expiry divisor is set
    event SetExpiryDivisor(uint256 newExpiryDivisor);

    /// @dev emitted when a new interest fee rate is set
    event SetInterestFeeRate(uint256 newInterestFeeRate);

    /// @dev emitted when a new reward fee rate is set
    event SetRewardFeeRate(uint256 newRewardFeeRate);

    /// @dev emitted when a treasury address is set
    event SetTreasury(address indexed treasury);

    /**
     * @notice returns the PT address for the corresponding (`SY`) token and (`expiry`), if created
     * @dev if the corresponding PY pair has not been created, returns `address(0)` instead
     */ 
    function getPT(address SY, uint256 expiry) external view returns (address);

    /**
     * @notice returns the YT address for the corresponding (`SY`) token and (`expiry`), if created
     * @dev if the corresponding PY pair has not been created, returns `address(0)` instead
     */
    function getYT(address SY, uint256 expiry) external view returns (address);

    /**
     * @notice returns the current expiry divisor
     */
    function expiryDivisor() external view returns (uint96);

    /**
     * @notice returns the current interest fee rate
     */
    function interestFeeRate() external view returns (uint128);

    /**
     * @notice returns the current reward fee rate
     */
    function rewardFeeRate() external view returns (uint128);

    /**
     * @notice returns the current treasury address
     */
    function treasury() external view returns (address);

    /**
     * @notice checks if an address is a created PT token
     */
    function isPT(address) external view returns (bool);

    /**
     * @notice checks if an address is a created YT token
     */ 
    function isYT(address) external view returns (bool);
}
