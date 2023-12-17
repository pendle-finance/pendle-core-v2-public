// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

struct BulkSellerState {
    uint256 rateTokenToSy;
    uint256 rateSyToToken;
    uint256 totalToken;
    uint256 totalSy;
    uint256 feeRate;
}

interface IPBulkSeller {
    event SwapExactTokenForSy(address receiver, uint256 netTokenIn, uint256 netSyOut);
    event SwapExactSyForToken(address receiver, uint256 netSyIn, uint256 netTokenOut);
    event RateUpdated(
        uint256 newRateTokenToSy,
        uint256 newRateSyToToken,
        uint256 oldRateTokenToSy,
        uint256 oldRateSyToToken
    );
    event ReBalanceTokenToSy(
        uint256 netTokenDeposit,
        uint256 netSyFromToken,
        uint256 newTokenProp,
        uint256 oldTokenProp
    );
    event ReBalanceSyToToken(uint256 netSyRedeem, uint256 netTokenFromSy, uint256 newTokenProp, uint256 oldTokenProp);
    event ReserveUpdated(uint256 totalToken, uint256 totalSy);
    event FeeRateUpdated(uint256 newFeeRate, uint256 oldFeeRate);

    function swapExactTokenForSy(
        address receiver,
        uint256 netTokenIn,
        uint256 minSyOut
    ) external payable returns (uint256 netSyOut);

    function swapExactSyForToken(
        address receiver,
        uint256 exactSyIn,
        uint256 minTokenOut,
        bool swapFromInternalBalance
    ) external returns (uint256 netTokenOut);

    function SY() external view returns (address);

    function token() external view returns (address);

    function readState() external view returns (BulkSellerState memory);
}
