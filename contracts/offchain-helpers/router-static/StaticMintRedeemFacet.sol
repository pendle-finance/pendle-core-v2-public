// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPBulkSeller.sol";

contract StaticMintRedeemFacet {
    using Math for uint256;
    using BulkSellerMathCore for BulkSellerState;

    function mintPYFromSyStatic(address YT, uint256 amountSyToMint)
        public
        returns (uint256 amountPY)
    {
        IPYieldToken _YT = IPYieldToken(YT);
        if (_YT.isExpired()) revert Errors.YCExpired();
        return amountSyToMint.mulDown(_YT.pyIndexCurrent());
    }

    function redeemPYToSyStatic(address YT, uint256 amountPYToRedeem)
        public
        returns (uint256 amountPY)
    {
        IPYieldToken _YT = IPYieldToken(YT);
        return amountPYToRedeem.divDown(_YT.pyIndexCurrent());
    }

    function mintPYFromBaseStatic(
        address YT,
        address baseToken,
        uint256 amountBaseToken,
        address bulk
    ) external returns (uint256 amountPY) {
        IStandardizedYield SY = IStandardizedYield(IPYieldToken(YT).SY());
        uint256 amountSy = previewDepositStatic(SY, baseToken, amountBaseToken, bulk);
        return mintPYFromSyStatic(YT, amountSy);
    }

    function redeemPYToBaseStatic(
        address YT,
        uint256 amountPYToRedeem,
        address baseToken,
        address bulk
    ) external returns (uint256 amountBaseToken) {
        IStandardizedYield SY = IStandardizedYield(IPYieldToken(YT).SY());
        uint256 amountSy = redeemPYToSyStatic(YT, amountPYToRedeem);
        return previewRedeemStatic(SY, baseToken, amountSy, bulk);
    }

    function previewDepositStatic(
        IStandardizedYield SY,
        address baseToken,
        uint256 amountToken,
        address bulk
    ) public view returns (uint256 amountSy) {
        if (bulk != address(0)) {
            BulkSellerState memory state = IPBulkSeller(bulk).readState();
            return state.calcSwapExactTokenForSy(amountToken);
        } else {
            return SY.previewDeposit(baseToken, amountToken);
        }
    }

    function previewRedeemStatic(
        IStandardizedYield SY,
        address baseToken,
        uint256 amountSy,
        address bulk
    ) public view returns (uint256 amountBaseToken) {
        if (bulk != address(0)) {
            BulkSellerState memory state = IPBulkSeller(bulk).readState();
            return state.calcSwapExactSyForToken(amountSy);
        } else {
            return SY.previewRedeem(baseToken, amountSy);
        }
    }
}