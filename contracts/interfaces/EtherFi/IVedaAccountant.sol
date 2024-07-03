// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

interface IVedaAccountant {
    function getRateInQuoteSafe(address quote) external view returns (uint256 rateInQuote);
}
