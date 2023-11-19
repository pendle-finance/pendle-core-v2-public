// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPMarketFactory {
    struct FeeConfig {
        uint80 lnFeeRateRoot;
        uint8 reserveFeePercent;
        bool active;
    }

    event NewMarketConfig(address indexed treasury, uint80 defaultLnFeeRateRoot, uint8 reserveFeePercent);
    event SetOverriddenFee(address indexed router, uint80 lnFeeRateRoot, uint8 reserveFeePercent);
    event UnsetOverriddenFee(address indexed router);

    event CreateNewMarket(address indexed market, address indexed PT, int256 scalarRoot, int256 initialAnchor);

    function isValidMarket(address market) external view returns (bool);

    // If this is changed, change the readState function in market as well
    function getMarketConfig(
        address router
    ) external view returns (address treasury, uint80 lnFeeRateRoot, uint8 reserveFeePercent);
}
