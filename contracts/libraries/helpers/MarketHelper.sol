// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../SuperComposableYield/ISuperComposableYield.sol";
import "../../interfaces/IPMarket.sol";

library MarketHelper {
    struct MarketStruct {
        IPMarket market;
        ISuperComposableYield SCY;
        IPOwnershipToken OT;
        IPYieldToken YT;
    }

    function readMarketInfo(address marketAddr) internal view returns (MarketStruct memory res) {
        IPMarket market = IPMarket(marketAddr);
        IPOwnershipToken OT = IPOwnershipToken(market.OT());
        res = MarketStruct({
            market: market,
            SCY: ISuperComposableYield(market.SCY()),
            OT: OT,
            YT: IPYieldToken(OT.YT())
        });
    }
}
