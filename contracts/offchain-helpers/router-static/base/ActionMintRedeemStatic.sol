// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../../interfaces/IPRouterStatic.sol";
import "./StorageLayout.sol";

contract ActionMintRedeemStatic is StorageLayout, IPActionMintRedeemStatic {
    using PMath for uint256;

    function mintPyFromSyStatic(address YT, uint256 netSyToMint) public view returns (uint256 netPYOut) {
        if (IPYieldToken(YT).isExpired()) revert Errors.YCExpired();
        return netSyToMint.mulDown(pyIndexCurrentViewYt(YT));
    }

    function redeemPyToSyStatic(address YT, uint256 netPYToRedeem) public view returns (uint256 netSyOut) {
        return netPYToRedeem.divDown(pyIndexCurrentViewYt(YT));
    }

    function mintPyFromTokenStatic(
        address YT,
        address tokenIn,
        uint256 netTokenIn
    ) external view returns (uint256 netPyOut) {
        address SY = IPYieldToken(YT).SY();
        uint256 netSyReceived = mintSyFromTokenStatic(SY, tokenIn, netTokenIn);
        netPyOut = mintPyFromSyStatic(YT, netSyReceived);
    }

    function redeemPyToTokenStatic(
        address YT,
        uint256 netPYToRedeem,
        address tokenOut
    ) external view returns (uint256 netTokenOut) {
        address SY = IPYieldToken(YT).SY();
        uint256 netSyReceived = redeemPyToSyStatic(YT, netPYToRedeem);
        netTokenOut = redeemSyToTokenStatic(SY, tokenOut, netSyReceived);
    }

    function mintSyFromTokenStatic(
        address SY,
        address tokenIn,
        uint256 netTokenIn
    ) public view returns (uint256 netSyOut) {
        return IStandardizedYield(SY).previewDeposit(tokenIn, netTokenIn);
    }

    function redeemSyToTokenStatic(
        address SY,
        address tokenOut,
        uint256 netSyIn
    ) public view returns (uint256 netTokenOut) {
        return IStandardizedYield(SY).previewRedeem(tokenOut, netSyIn);
    }

    function getAmountTokenToMintSy(
        address SY,
        address tokenIn,
        uint256 netSyOut
    ) external view returns (uint256 netTokenIn) {
        uint256 pivotAmount;

        if (tokenIn == address(0)) pivotAmount = 1e18;
        else pivotAmount = 10 ** IStandardizedYield(SY).decimals();

        uint256 low = pivotAmount;
        {
            while (true) {
                uint256 lowSyOut = mintSyFromTokenStatic(SY, tokenIn, low);
                if (lowSyOut >= netSyOut) low /= 10;
                else break;
            }
        }

        uint256 high = pivotAmount;
        {
            while (true) {
                uint256 highSyOut = mintSyFromTokenStatic(SY, tokenIn, high);
                if (highSyOut < netSyOut) high *= 10;
                else break;
            }
        }

        while (low <= high) {
            uint256 mid = (low + high) / 2;
            uint256 syOut = mintSyFromTokenStatic(SY, tokenIn, mid);

            if (syOut >= netSyOut) {
                netTokenIn = mid;
                high = mid - 1;
            } else {
                low = mid + 1;
            }
        }

        assert(netTokenIn > 0);
    }

    function pyIndexCurrentViewMarket(address market) public view returns (uint256) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        return pyIndexCurrentViewYt(address(YT));
    }

    function pyIndexCurrentViewYt(address yt) public view returns (uint256) {
        IPYieldToken YT = IPYieldToken(yt);
        IStandardizedYield SY = IStandardizedYield(YT.SY());

        uint256 syIndex = SY.exchangeRate();
        uint256 pyIndexStored = YT.pyIndexStored();

        if (YT.doCacheIndexSameBlock() && YT.pyIndexLastUpdatedBlock() == block.number) {
            return pyIndexStored;
        } else {
            return PMath.max(syIndex, pyIndexStored);
        }
    }
}
