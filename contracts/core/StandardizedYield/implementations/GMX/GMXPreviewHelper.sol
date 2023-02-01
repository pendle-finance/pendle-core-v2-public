// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../../../interfaces/GMX/IVault.sol";
import "../../../../interfaces/GMX/IVaultPriceFeed.sol";

contract GMXPreviewHelper {
    IVault public vault;

    // Based on Vault functions

    function buyUSDG(address _token, uint256 tokenAmount) internal view returns (uint256) {
        require(tokenAmount > 0);

        uint256 price = getMinPrice(_token);

        uint256 usdgAmount = (tokenAmount * price) / vault.PRICE_PRECISION();
        usdgAmount = vault.adjustForDecimals(usdgAmount, _token, vault.usdg());
        require(usdgAmount > 0);

        uint256 feeBasisPoints = vault.getFeeBasisPoints(
            _token,
            usdgAmount,
            vault.mintBurnFeeBasisPoints(),
            vault.taxBasisPoints(),
            true
        );
        uint256 amountAfterFees = _collectSwapFees(_token, tokenAmount, feeBasisPoints);
        uint256 mintAmount = (amountAfterFees * price) / vault.PRICE_PRECISION();
        mintAmount = vault.adjustForDecimals(mintAmount, _token, vault.usdg());

        return mintAmount;
    }

    function sellUSDG(address _token, uint256 usdgAmount) internal view returns (uint256) {
        require(usdgAmount > 0);

        uint256 redemptionAmount = getRedemptionAmount(_token, usdgAmount);
        require(redemptionAmount > 0);

        uint256 feeBasisPoints = vault.getFeeBasisPoints(
            _token,
            usdgAmount,
            vault.mintBurnFeeBasisPoints(),
            vault.taxBasisPoints(),
            false
        );
        uint256 amountOut = _collectSwapFees(_token, redemptionAmount, feeBasisPoints);
        require(amountOut > 0);

        return amountOut;
    }

    function getMinPrice(address _token) private view returns (uint256) {
        // includeAmmPrice = true, useSwapPricing = false
        return IVaultPriceFeed(vault.priceFeed()).getPrice(_token, false, true, false);
    }

    function getMaxPrice(address _token) private view returns (uint256) {
        // includeAmmPrice = true, useSwapPricing = true
        return IVaultPriceFeed(vault.priceFeed()).getPrice(_token, true, true, true);
    }

    function getRedemptionAmount(address _token, uint256 _usdgAmount)
        private
        view
        returns (uint256)
    {
        uint256 price = getMaxPrice(_token);
        uint256 redemptionAmount = (_usdgAmount * vault.PRICE_PRECISION()) / price;
        return vault.adjustForDecimals(redemptionAmount, vault.usdg(), _token);
    }

    function _collectSwapFees(
        address _token,
        uint256 _amount,
        uint256 _feeBasisPoints
    ) private view returns (uint256) {
        uint256 afterFeeAmount = (_amount * (vault.BASIS_POINTS_DIVISOR() - _feeBasisPoints)) /
            (vault.BASIS_POINTS_DIVISOR());
        return afterFeeAmount;
    }
}
