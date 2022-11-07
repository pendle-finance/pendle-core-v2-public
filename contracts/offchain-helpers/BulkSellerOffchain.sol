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

    function getCurrentState(IPBulkSeller bulk)
        external
        view
        returns (
            BulkSellerState memory state,
            uint256 tokenProp,
            uint256 hypoTokenBal
        )
    {
        state = bulk.readState();

        tokenProp = state.getTokenProp();
        hypoTokenBal =
            state.totalToken +
            IStandardizedYield(bulk.SY()).previewRedeem(bulk.token(), state.totalSy);
    }
    
    function calcCurrentRatesWithAmount(
        IPBulkSeller bulk,
        uint256 hypoTotalToken,
        uint256 hypoTotalSy
    ) external view returns (uint256 rateTokenToSy, uint256 rateSyToToken) {
        address SY = bulk.SY();
        address token = bulk.token();

        {
            uint256 netSyFromToken = IStandardizedYield(SY).previewDeposit(token, hypoTotalToken);
            rateTokenToSy = netSyFromToken.divDown(hypoTotalToken);
        }

        {
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
