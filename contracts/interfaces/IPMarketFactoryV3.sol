// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPMarketFactoryV3 {
    event SetOverriddenFee(address indexed router, address indexed market, uint80 lnFeeRateRoot);

    event CreateNewMarket(
        address indexed market,
        address indexed PT,
        int256 scalarRoot,
        int256 initialAnchor,
        uint256 lnFeeRateRoot
    );

    event NewTreasuryAndFeeReserve(address indexed treasury, uint8 reserveFeePercent);

    function isValidMarket(address market) external view returns (bool);

    // If this is changed, change the readState function in market as well
    function getMarketConfig(
        address market,
        address router
    ) external view returns (address treasury, uint80 overriddenFee, uint8 reserveFeePercent);

    function createNewMarket(
        address PT,
        int256 scalarRoot,
        int256 initialAnchor,
        uint80 lnFeeRateRoot
    ) external returns (address market);
}
