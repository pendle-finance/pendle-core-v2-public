// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./BulkSellerMathCore.sol";
import "./BulkSeller.sol";

// upgradable bla bla
contract BulkSellerOffchain {
    using BulkSellerMathCore for BulkSellerState;
    using Math for uint256;

    // rmb to add fee here
    function calcCurrentRates(IPBulkSeller bulk)
        external
        view
        returns (uint256 rateTokenToSy, uint256 rateSyToToken)
    {
        BulkSellerState memory state = bulk.readState();
        address SY = bulk.SY();
        address token = bulk.token();

        {
            uint256 hypoTotalToken = state.totalToken +
                state.calcSwapExactSyForToken(state.totalSy);
            uint256 netSyFromToken = IStandardizedYield(SY).previewDeposit(token, hypoTotalToken);

            rateTokenToSy = netSyFromToken.divDown(hypoTotalToken);
        }

        {
            uint256 hypoTotalSy = state.totalSy + state.calcSwapExactTokenForSy(state.totalToken);
            uint256 netTokenFromSy = IStandardizedYield(SY).previewRedeem(token, hypoTotalSy);

            rateSyToToken = netTokenFromSy.divDown(hypoTotalSy);
        }
    }

    // TODO: pause contract when rate is bad compared to market
    // TODO: Sound alarm if updates fail
    // TODO: audit even the typescript code
    // TODO: add a max with currentRate to guarantee no loss?
    // TODO: pause immediately if lost enough money
}
