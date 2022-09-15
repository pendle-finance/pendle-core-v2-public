// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../interfaces/IPActionSwapPTYT.sol";
import "../../interfaces/IPMarket.sol";
import "./base/CallbackHelper.sol";

contract ActionSwapPTYT is IPActionSwapPTYT, CallbackHelper {
    using MarketMathCore for MarketState;
    using MarketApproxPtInLib for MarketState;
    using MarketApproxPtOutLib for MarketState;
    using Math for uint256;
    using Math for int256;
    using SafeERC20 for IERC20;
    using PYIndexLib for IPYieldToken;
    using SafeERC20 for ISuperComposableYield;
    using SafeERC20 for IPYieldToken;
    using SafeERC20 for IPPrincipalToken;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor() //solhint-disable-next-line no-empty-blocks
    {

    }

    function swapExactPtForYt(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minYtOut,
        ApproxParams calldata guessTotalPtToSwap
    ) external returns (uint256 netYtOut, uint256 netScyFee) {
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();
        MarketState memory state = IPMarket(market).readState();

        PT.safeTransferFrom(msg.sender, market, exactPtIn);

        uint256 totalPtToSwap;
        (netYtOut, , totalPtToSwap, netScyFee) = state.approxSwapExactPtForYt(
            YT.newIndex(),
            exactPtIn,
            block.timestamp,
            guessTotalPtToSwap
        );

        require(netYtOut >= minYtOut, "insufficient YT out");
        IPMarket(market).swapExactPtForScy(
            address(YT),
            totalPtToSwap,
            _encodeSwapExactPtForYt(receiver, exactPtIn, minYtOut)
        );

        emit SwapPtAndYt(msg.sender, market, receiver, exactPtIn.neg(), netYtOut.Int());
    }

    function swapExactYtForPt(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minPtOut,
        ApproxParams calldata guessTotalPtSwapped
    ) external returns (uint256 netPtOut, uint256 netScyFee) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        MarketState memory state = IPMarket(market).readState();

        YT.safeTransferFrom(msg.sender, address(YT), exactYtIn);

        uint256 totalPtSwapped;
        (netPtOut, , totalPtSwapped, netScyFee) = state.approxSwapExactYtForPt(
            YT.newIndex(),
            exactYtIn,
            block.timestamp,
            guessTotalPtSwapped
        );

        require(netPtOut >= minPtOut, "insufficient PT out");

        IPMarket(market).swapScyForExactPt(
            address(this),
            totalPtSwapped,
            _encodeSwapExactYtForPt(receiver, exactYtIn, minPtOut)
        );

        emit SwapPtAndYt(msg.sender, market, receiver, netPtOut.Int(), exactYtIn.neg());
    }
}
