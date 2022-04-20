// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

interface IPMarketFactory {
    function isValidMarket(address market) external view returns (bool);

    function treasury() external view returns (address);

    // If this is changed, change the readState function in market as well
    function marketConfig()
        external
        view
        returns (
            address treasury,
            uint96 lnFeeRateRoot,
            uint32 rateOracleTimeWindow,
            uint8 reserveFeePercent
        );
}
