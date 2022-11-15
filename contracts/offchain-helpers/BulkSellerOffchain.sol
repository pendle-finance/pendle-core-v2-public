// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../core/BulkSeller/BulkSellerMathCore.sol";
import "../core/BulkSeller/BulkSeller.sol";
import "hardhat/console.sol";

contract BulkSellerOffchain {
    using BulkSellerMathCore for BulkSellerState;
    using Math for uint256;

    function calcCurrentRates(IPBulkSeller bulk)
        external
        view
        returns (uint256 rateTokenToSy, uint256 rateSyToToken)
    {
        BulkSellerState memory state = bulk.readState();
        address SY = bulk.SY();
        address token = bulk.token();

        {
            uint256 hypoTotalToken = state.totalToken + state.totalSy.mulDown(state.rateSyToToken);
            uint256 netSyFromToken = IStandardizedYield(SY).previewDeposit(token, hypoTotalToken);

            rateTokenToSy = netSyFromToken.divDown(hypoTotalToken);
        }

        {
            uint256 hypoTotalSy = state.totalSy + state.totalToken.mulDown(state.rateTokenToSy);
            uint256 netTokenFromSy = IStandardizedYield(SY).previewRedeem(token, hypoTotalSy);
            rateSyToToken = netTokenFromSy.divDown(hypoTotalSy);
        }
    }
}
