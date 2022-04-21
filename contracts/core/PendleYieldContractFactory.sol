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

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../libraries/helpers/ExpiryUtilsLib.sol";
import "../periphery/PermissionsV2Upg.sol";
import "../interfaces/IPYieldContractFactory.sol";

import "./PendlePrincipalToken.sol";
import "./PendleYieldToken.sol";

contract PendleYieldContractFactory is PermissionsV2Upg, IPYieldContractFactory {
    using ExpiryUtils for string;

    string public constant OT_PREFIX = "PT";
    string public constant YT_PREFIX = "YT";

    uint256 public expiryDivisor;
    uint256 public interestFeeRate;
    address public treasury;

    // SCY => expiry => address
    mapping(address => mapping(uint256 => address)) public getOT;
    mapping(address => mapping(uint256 => address)) public getYT;
    mapping(address => bool) public isOT;
    mapping(address => bool) public isYT;

    constructor(
        uint256 _expiryDivisor,
        uint256 _interestFeeRate,
        address _treasury,
        address _governanceManager
    ) PermissionsV2Upg(_governanceManager) {
        require(_expiryDivisor != 0, "zero value");
        require(treasury != address(0), "zero address");

        expiryDivisor = _expiryDivisor;
        interestFeeRate = _interestFeeRate;
        treasury = _treasury;
    }

    function createYieldContract(address SCY, uint256 expiry)
        external
        returns (address PT, address YT)
    {
        require(expiry % expiryDivisor == 0, "must be multiple of divisor");

        require(getOT[SCY][expiry] == address(0), "OT_EXISTED");

        ISuperComposableYield _SCY = ISuperComposableYield(SCY);

        uint8 assetDecimals = _SCY.assetDecimals();

        PT = address(
            new PendlePrincipalToken(
                SCY,
                OT_PREFIX.concat(_SCY.name(), expiry, " "),
                OT_PREFIX.concat(_SCY.symbol(), expiry, "-"),
                assetDecimals,
                expiry
            )
        );

        YT = address(
            new PendleYieldToken(
                SCY,
                PT,
                YT_PREFIX.concat(_SCY.name(), expiry, " "),
                YT_PREFIX.concat(_SCY.symbol(), expiry, "-"),
                assetDecimals,
                expiry
            )
        );

        IPPrincipalToken(PT).initialize(YT);

        getOT[SCY][expiry] = PT;
        getYT[SCY][expiry] = YT;
        isOT[PT] = true;
        isYT[YT] = true;

        emit CreateYieldContract(SCY, PT, YT, expiry);
    }

    function setExpiryDivisor(uint256 newExpiryDivisor) external onlyGovernance {
        require(newExpiryDivisor != 0, "zero value");
        expiryDivisor = newExpiryDivisor;
        emit SetExpiryDivisor(newExpiryDivisor);
    }

    function setInterestFeeRate(uint256 newInterestFeeRate) external onlyGovernance {
        interestFeeRate = newInterestFeeRate;
        emit SetInterestFeeRate(newInterestFeeRate);
    }

    function setTreasury(address newTreasury) external onlyGovernance {
        require(newTreasury != address(0), "zero address");
        treasury = newTreasury;
        emit SetTreasury(treasury);
    }
}
