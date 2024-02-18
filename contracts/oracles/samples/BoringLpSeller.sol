// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import "../../interfaces/IPMarket.sol";

abstract contract BoringLpSeller {
    bytes internal constant EMPTY_BYTES = abi.encode();

    constructor() {}

    /// @dev slippage control should be done on a higher level with the returned parameter
    /// @param market market address
    /// @param netLpIn amount of Lp to sell
    /// @param tokenOut should be included in SY.getTokensOut()
    /// @return netTokenOut amount of token out
    function _sellLpForToken(address market, uint256 netLpIn, address tokenOut) internal returns (uint256 netTokenOut) {
        (IStandardizedYield SY, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();

        IPMarket(market).transfer(market, netLpIn);

        uint256 netSyToRedeem;

        if (PT.isExpired()) {
            (uint256 netSyRemoved, ) = IPMarket(market).burn(address(SY), address(YT), netLpIn);
            uint256 netSyFromPt = YT.redeemPY(address(SY));
            netSyToRedeem = netSyRemoved + netSyFromPt;
        } else {
            (uint256 netSyRemoved, uint256 netPtRemoved) = IPMarket(market).burn(address(SY), market, netLpIn);
            (uint256 netSySwappedOut, ) = IPMarket(market).swapExactPtForSy(address(SY), netPtRemoved, EMPTY_BYTES);
            netSyToRedeem = netSyRemoved + netSySwappedOut;
        }

        netTokenOut = SY.redeem(address(this), netSyToRedeem, tokenOut, 0, true);
    }
}
