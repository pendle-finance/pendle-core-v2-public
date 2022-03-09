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
import "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";
import "../libraries/helpers/ExpiryUtilsLib.sol";

import "../interfaces/IPLiquidYieldToken.sol";
import "../interfaces/IPYieldContractFactory.sol";

import "./PendleOwnershipToken.sol";
import "./PendleYieldToken.sol";

contract PendleYieldContractFactory is IPYieldContractFactory {
    using ExpiryUtils for string;
    using EnumerableSet for EnumerableSet.AddressSet;

    string public constant OT_PREFIX = "OT";
    string public constant YT_PREFIX = "YT";

    // LYT => expiry => address
    mapping(address => mapping(uint256 => address)) public getOT;
    mapping(address => mapping(uint256 => address)) public getYT;

    function newYieldContracts(address LYT, uint256 expiry)
        external
        returns (address OT, address YT)
    {
        // add conditions for expiry
        require(getOT[LYT][expiry] == address(0), "OT_EXISTED");

        uint8 underlyingAssetDecimals = IPLiquidYieldToken(LYT).underlyingDecimals();

        OT = address(
            new PendleOwnershipToken(
                LYT,
                OT_PREFIX.concat(IPLiquidYieldToken(LYT).name(), expiry, " "),
                OT_PREFIX.concat(IPLiquidYieldToken(LYT).symbol(), expiry, "-"),
                underlyingAssetDecimals,
                expiry
            )
        );

        YT = address(
            new PendleYieldToken(
                LYT,
                OT,
                YT_PREFIX.concat(IPLiquidYieldToken(LYT).name(), expiry, " "),
                YT_PREFIX.concat(IPLiquidYieldToken(LYT).symbol(), expiry, "-"),
                underlyingAssetDecimals,
                expiry
            )
        );

        IPOwnershipToken(OT).initialize(YT);

        getOT[LYT][expiry] = OT;
        getYT[LYT][expiry] = YT;
    }
}
