// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import "../../interfaces/IPMarket.sol";

abstract contract BoringPtSeller {
    bytes internal constant EMPTY_BYTES = abi.encode();

    constructor() {}

    /// @dev slippage control should be done on a higher level with the returned parameter
    /// @param market market address
    /// @param netPtIn amount of Pt to sell
    /// @param tokenOut should be included in SY.getTokensOut()
    /// @return netTokenOut amount of token out
    function _sellPtForToken(address market, uint256 netPtIn, address tokenOut) internal returns (uint256 netTokenOut) {
        (IStandardizedYield SY, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 netSyOut;
        if (PT.isExpired()) {
            PT.transfer(address(YT), netPtIn);
            netSyOut = YT.redeemPY(address(SY));
        } else {
            // safeTransfer not required
            PT.transfer(market, netPtIn);
            (netSyOut, ) = IPMarket(market).swapExactPtForSy(
                address(SY), // better gas optimization to transfer SY directly to itself and burn
                netPtIn,
                EMPTY_BYTES
            );
        }

        netTokenOut = SY.redeem(address(this), netSyOut, tokenOut, 0, true);
    }
}
