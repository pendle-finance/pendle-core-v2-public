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
        address tokenIn,
        uint256 amountTokenIn,
        address bulk
    ) external returns (uint256 amountSy, uint256 amountPY) {
        IStandardizedYield SY = IStandardizedYield(IPYieldToken(YT).SY());
        amountSy = previewDepositStatic(SY, tokenIn, amountTokenIn, bulk);
        amountPY = mintPYFromSyStatic(YT, amountSy);
    }

    function redeemPYToBaseStatic(
        address YT,
        uint256 amountPYToRedeem,
        address tokenOut,
        address bulk
    ) external returns (uint256 amountSy, uint256 amountTokenOut) {
        IStandardizedYield SY = IStandardizedYield(IPYieldToken(YT).SY());
        amountSy = redeemPYToSyStatic(YT, amountPYToRedeem);
        amountTokenOut = previewRedeemStatic(SY, tokenOut, amountSy, bulk);
    }

    function previewDepositStatic(
        IStandardizedYield SY,
        address tokenIn,
        uint256 amountTokenIn,
        address bulk
    ) public view returns (uint256 amountSyOut) {
        if (bulk != address(0)) {
            BulkSellerState memory state = IPBulkSeller(bulk).readState();
            return state.calcSwapExactTokenForSy(amountTokenIn);
        } else {
            return SY.previewDeposit(tokenIn, amountTokenIn);
        }
    }

    function previewRedeemStatic(
        IStandardizedYield SY,
        address tokenOut,
        uint256 amountSyIn,
        address bulk
    ) public view returns (uint256 amountTokenOut) {
        if (bulk != address(0)) {
            BulkSellerState memory state = IPBulkSeller(bulk).readState();
            return state.calcSwapExactSyForToken(amountSyIn);
        } else {
            return SY.previewRedeem(tokenOut, amountSyIn);
        }
    }

    function getAmountTokenToMintSy(
        IStandardizedYield SY,
        address tokenIn,
        address bulk,
        uint256 netSyOut
    ) public view returns (uint256 netTokenIn) {
        uint256 pivotAmount = 10**IERC20Metadata(tokenIn).decimals();

        uint256 low = pivotAmount;
        {
            while (true) {
                uint256 lowSyOut = previewDepositStatic(SY, tokenIn, low, bulk);
                if (lowSyOut >= netSyOut) low /= 10;
                else break;
            }
        }

        uint256 high = pivotAmount;
        {
            while (true) {
                uint256 highSyOut = previewDepositStatic(SY, tokenIn, high, bulk);
                if (highSyOut < netSyOut) high *= 10;
                else break;
            }
        }

        while (low <= high) {
            uint256 mid = (low + high) / 2;
            uint256 syOut = previewDepositStatic(SY, tokenIn, mid, bulk);

            if (syOut >= netSyOut) {
                netTokenIn = mid;
                high = mid - 1;
            } else {
                low = mid + 1;
            }
        }

        assert(netTokenIn > 0);
    }

    function getAmountSyToRedeemToken(
        IStandardizedYield SY,
        address tokenOut,
        address bulk,
        uint256 netTokenOut
    ) public view returns (uint256 netSyIn) {
        uint256 pivotAmount = 10**SY.decimals();

        uint256 low = pivotAmount;
        {
            while (true) {
                uint256 lowTokenOut = previewRedeemStatic(SY, tokenOut, low, bulk);
                if (lowTokenOut >= netTokenOut) low /= 10;
                else break;
            }
        }

        uint256 high = pivotAmount;
        {
            while (true) {
                uint256 highTokenOut = previewRedeemStatic(SY, tokenOut, high, bulk);
                if (highTokenOut > netTokenOut) high *= 10;
                else break;
            }
        }

        while (low <= high) {
            uint256 mid = (low + high) / 2;
            uint256 midTokenOut = previewRedeemStatic(SY, tokenOut, mid, bulk);
             
            if (midTokenOut >= netTokenOut) {
                netSyIn = mid;
                high = mid - 1;
            } else {
                low = mid + 1;
            }
        }

        assert(netSyIn > 0);
    }
}