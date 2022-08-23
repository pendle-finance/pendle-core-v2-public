// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPActionMisc.sol";

contract ActionMisc is IPActionMisc {
    using Math for uint256;

    function consult(address market, uint32 secondsAgo)
        external
        view
        returns (uint96 lnImpliedRateMean)
    {
        require(secondsAgo != 0, "time range is zero");
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;
        uint216[] memory lnImpliedRateCumulatives = IPMarket(market).observe(secondsAgos);
        return
            (uint256(lnImpliedRateCumulatives[1] - lnImpliedRateCumulatives[0]) / secondsAgo)
                .Uint96();
    }
}
