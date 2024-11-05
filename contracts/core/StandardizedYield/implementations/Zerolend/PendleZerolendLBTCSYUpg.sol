// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "../AaveV3/PendleAaveV3WithRewardsSYUpg.sol";
import "../../../../interfaces/IPExchangeRateOracle.sol";

contract PendleZerolendLBTCSYUpg is PendleAaveV3WithRewardsSYUpg {
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address public constant Z0LBTC = 0xcABB8fa209CcdF98a7A0DC30b1979fC855Cb3Eb3;
    address public constant ZEROLEND_POOL = 0xCD2b31071119D7eA449a9D211AC8eBF7Ee97F987;
    
    address public constant ZEROLEND_INCENTIVE_CONTROLLER = address(0); // no reward currently, leave as address(0) for gas saving
    address public constant ZERO = 0x2Da17fAf782ae884faf7dB2208BBC66b6E085C22;
    address public constant LBTC_ORACLE = 0x1F0318B5Ab2c4084692986A2C25916Cec1195cD9;

    constructor() PendleAaveV3WithRewardsSYUpg(ZEROLEND_POOL, Z0LBTC, ZEROLEND_INCENTIVE_CONTROLLER, ZERO) {}

    function exchangeRate() public view virtual override returns (uint256) {
        return PMath.mulDown(super.exchangeRate(), IPExchangeRateOracle(LBTC_ORACLE).getExchangeRate());
    }

    function assetInfo()
        external
        view
        virtual
        override
        returns (AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (AssetType.TOKEN, WBTC, IERC20Metadata(WBTC).decimals());
    }
}
