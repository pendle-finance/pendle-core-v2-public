// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../../interfaces/IPRouterStatic.sol";
import "../../../interfaces/IPBulkSeller.sol";
import "../../../interfaces/IPBulkSellerFactory.sol";
import "./StorageLayout.sol";

contract ActionMintRedeemStatic is StorageLayout, IPActionMintRedeemStatic {
    using Math for uint256;
    using BulkSellerMathCore for BulkSellerState;

    function mintPyFromSyStatic(
        address YT,
        uint256 netSyToMint
    ) public returns (uint256 netPYOut) {
        if (IPYieldToken(YT).isExpired()) revert Errors.YCExpired();
        return netSyToMint.mulDown(IPYieldToken(YT).pyIndexCurrent());
    }

    function redeemPyToSyStatic(
        address YT,
        uint256 netPYToRedeem
    ) public returns (uint256 netSyOut) {
        return netPYToRedeem.divDown(IPYieldToken(YT).pyIndexCurrent());
    }

    function mintPyFromTokenStatic(
        address YT,
        address tokenIn,
        uint256 netTokenIn,
        address bulk
    ) external returns (uint256 netPyOut) {
        address SY = IPYieldToken(YT).SY();
        uint256 netSyReceived = mintSyFromTokenStatic(SY, tokenIn, netTokenIn, bulk);
        netPyOut = mintPyFromSyStatic(YT, netSyReceived);
    }

    function redeemPyToTokenStatic(
        address YT,
        uint256 netPYToRedeem,
        address tokenOut,
        address bulk
    ) external returns (uint256 netTokenOut) {
        address SY = IPYieldToken(YT).SY();
        uint256 netSyReceived = redeemPyToSyStatic(YT, netPYToRedeem);
        netTokenOut = redeemSyToTokenStatic(SY, tokenOut, netSyReceived, bulk);
    }

    function mintSyFromTokenStatic(
        address SY,
        address tokenIn,
        uint256 netTokenIn,
        address bulk
    ) public view returns (uint256 netSyOut) {
        if (bulk != address(0)) {
            BulkSellerState memory state = _readBulkSellerState(bulk);
            return state.calcSwapExactTokenForSy(netTokenIn);
        } else {
            return IStandardizedYield(SY).previewDeposit(tokenIn, netTokenIn);
        }
    }

    function redeemSyToTokenStatic(
        address SY,
        address tokenOut,
        uint256 netSyIn,
        address bulk
    ) public view returns (uint256 netTokenOut) {
        if (bulk != address(0)) {
            BulkSellerState memory state = _readBulkSellerState(bulk);
            return state.calcSwapExactSyForToken(netSyIn);
        } else {
            return IStandardizedYield(SY).previewRedeem(tokenOut, netSyIn);
        }
    }

    function getAmountTokenToMintSy(
        address SY,
        address tokenIn,
        address bulk,
        uint256 netSyOut
    ) external view returns (uint256 netTokenIn) {
        uint256 pivotAmount;

        if (tokenIn == address(0)) pivotAmount = 1e18;
        else pivotAmount = 10 ** IStandardizedYield(SY).decimals();

        uint256 low = pivotAmount;
        {
            while (true) {
                uint256 lowSyOut = mintSyFromTokenStatic(SY, tokenIn, low, bulk);
                if (lowSyOut >= netSyOut) low /= 10;
                else break;
            }
        }

        uint256 high = pivotAmount;
        {
            while (true) {
                uint256 highSyOut = mintSyFromTokenStatic(SY, tokenIn, high, bulk);
                if (highSyOut < netSyOut) high *= 10;
                else break;
            }
        }

        while (low <= high) {
            uint256 mid = (low + high) / 2;
            uint256 syOut = mintSyFromTokenStatic(SY, tokenIn, mid, bulk);

            if (syOut >= netSyOut) {
                netTokenIn = mid;
                high = mid - 1;
            } else {
                low = mid + 1;
            }
        }

        assert(netTokenIn > 0);
    }

    function getBulkSellerInfo(
        address token,
        address SY,
        uint256 netTokenIn,
        uint256 netSyIn
    ) external view returns (address bulk, uint256 totalToken, uint256 totalSy) {
        if (address(bulkSellerFactory) == address(0)) return (address(0), 0, 0);

        bulk = bulkSellerFactory.get(token, SY);
        if (bulk == address(0)) return (address(0), 0, 0);

        BulkSellerState memory state = _readBulkSellerState(bulk);

        // Paused check
        if (state.rateTokenToSy == 0 || state.rateSyToToken == 0) {
            return (address(0), 0, 0);
        }

        // Liquidity check
        uint256 postFeeRateTokenToSy = state.rateTokenToSy.mulDown(Math.ONE - state.feeRate);
        uint256 postFeeRateSyToToken = state.rateSyToToken.mulDown(Math.ONE - state.feeRate);
        if (
            netTokenIn.mulDown(postFeeRateTokenToSy) > state.totalSy ||
            netSyIn.mulDown(postFeeRateSyToToken) > state.totalToken
        ) {
            return (address(0), 0, 0);
        }

        // return...
        totalToken = state.totalToken;
        totalSy = state.totalSy;
    }

    function _readBulkSellerState(address bulk) internal view returns (BulkSellerState memory) {
        return IPBulkSeller(bulk).readState();
    }
}
