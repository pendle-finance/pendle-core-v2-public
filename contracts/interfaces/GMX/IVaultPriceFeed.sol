// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVaultPriceFeed {
    function getPrice(
        address _token,
        bool _maximise,
        bool _includeAmmPrice,
        bool _useSwapPricing
    ) external view returns (uint256);
}
