// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../../../interfaces/Venus/IVenusToken.sol";
import "../../../../interfaces/Venus/IVenusInterestModel.sol";

abstract contract PendleVTokenRateHelper {
    // solhint-disable immutable-vars-naming
    // solhint-disable const-name-snakecase
    address public immutable vToken;
    uint256 private immutable initialExchangeRateMantissa;
    uint256 private constant borrowRateMaxMantissa = 0.0005e16;

    constructor(address _vToken, uint256 _initialExchangeRateMantissa) {
        vToken = _vToken;
        initialExchangeRateMantissa = _initialExchangeRateMantissa;
    }

    function _exchangeRateCurrentView() internal view returns (uint256) {
        uint256 currentBlock = block.number;

        uint256 accrualBlockPrior = IVenusToken(vToken).accrualBlockNumber();

        if (accrualBlockPrior == currentBlock) return IVenusToken(vToken).exchangeRateStored();

        /* Read the previous values out of storage */
        uint256 cashPrior = IVenusToken(vToken).getCash();
        uint256 borrowsPrior = IVenusToken(vToken).totalBorrows();
        uint256 reservesPrior = IVenusToken(vToken).totalReserves();

        /* Calculate the current borrow interest rate */
        uint256 borrowRateMantissa = IVenusInterestRateModel(IVenusToken(vToken).interestRateModel()).getBorrowRate(
            cashPrior,
            borrowsPrior,
            reservesPrior
        );

        if (borrowRateMantissa > borrowRateMaxMantissa) revert("borrowRate > borrowRateMax");
        // revert Errors.SYQiTokenBorrowRateTooHigh(borrowRateMantissa, borrowRateMaxMantissa);

        uint256 blockDelta = currentBlock - accrualBlockPrior;

        uint256 simpleInterestFactor = borrowRateMantissa * blockDelta;

        uint256 interestAccumulated = (simpleInterestFactor * borrowsPrior) / 1e18;

        uint256 totalBorrowsNew = interestAccumulated + borrowsPrior;

        uint256 totalReservesNew = (IVenusToken(vToken).reserveFactorMantissa() * interestAccumulated) /
            1e18 +
            reservesPrior;

        return _calcExchangeRate(IVenusToken(vToken).totalSupply(), cashPrior, totalBorrowsNew, totalReservesNew);
    }

    function _calcExchangeRate(
        uint256 totalSupply,
        uint256 totalCash,
        uint256 totalBorrows,
        uint256 totalReserves
    ) private view returns (uint256) {
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            return initialExchangeRateMantissa;
        } else {
            uint256 cashPlusBorrowsMinusReserves;
            uint256 exchangeRate;

            cashPlusBorrowsMinusReserves = totalCash + totalBorrows - totalReserves;

            exchangeRate = (cashPlusBorrowsMinusReserves * 1e18) / _totalSupply;

            return exchangeRate;
        }
    }
}
