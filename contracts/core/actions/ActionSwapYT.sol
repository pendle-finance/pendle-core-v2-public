// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./base/ActionBaseMintRedeem.sol";
import "./base/CallbackHelper.sol";
import "../../interfaces/IPActionSwapYT.sol";
import "../../interfaces/IPMarket.sol";
import "../../libraries/Errors.sol";

contract ActionSwapYT is IPActionSwapYT, ActionBaseMintRedeem, CallbackHelper {
    using Math for uint256;
    using Math for int256;
    using MarketMathCore for MarketState;
    using MarketApproxPtInLib for MarketState;
    using MarketApproxPtOutLib for MarketState;
    using SafeERC20 for ISuperComposableYield;
    using SafeERC20 for IPYieldToken;
    using PYIndexLib for IPYieldToken;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter)
        ActionBaseMintRedeem(_kyberSwapRouter) //solhint-disable-next-line no-empty-blocks
    {}

    /**
    * @notice swap exact SCY to YT with the help of flashswaps & YT tokenization / redemption
    * @dev inner working of this function:
     - `exactScyIn` SCY is transferred to YT contract
     - `market.swapExactPtForScy` is called, which will transfer SCY directly to YT contract & callback is invoked.
        Note that now we owe PT
     - in callback, all SCY in YT contract is used to mint PT + YT, with PT used to pay back the loan, and YT
        transferred to the receiver
    * @dev this function works in conjunction with ActionCallback
     */
    function swapExactScyForYt(
        address receiver,
        address market,
        uint256 exactScyIn,
        uint256 minYtOut,
        ApproxParams memory guessYtOut
    ) external returns (uint256 netYtOut, uint256 netScyFee) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        SCY.safeTransferFrom(msg.sender, address(YT), exactScyIn);

        (netYtOut, netScyFee) = _swapExactScyForYt(
            receiver,
            market,
            YT,
            exactScyIn,
            minYtOut,
            guessYtOut
        );

        emit SwapYtAndScy(msg.sender, market, receiver, netYtOut.Int(), exactScyIn.neg());
    }

    /**
    * @notice swap exact YT to SCY with the help of flashswaps & YT tokenization / redemption
    * @dev inner working of this function:
     - `exactYtIn` YT is transferred to YT contract
     - `market.swapScyForExactPt` is called, which will transfer PT directly to YT contract & callback is invoked.
        Note that now we owe SCY
     - in callback, all PT + YT in YT contract is used to redeem SCY. A portion of SCY is used to payback the loan,
        the rest is transferred to the `receiver`
    * @dev this function works in conjunction with ActionCallback
     */
    function swapExactYtForScy(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minScyOut
    ) external returns (uint256 netScyOut, uint256 netScyFee) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        YT.safeTransferFrom(msg.sender, address(YT), exactYtIn);

        (netScyOut, netScyFee) = _swapExactYtForScy(
            receiver,
            market,
            SCY,
            YT,
            exactYtIn,
            minScyOut
        );

        emit SwapYtAndScy(msg.sender, market, receiver, exactYtIn.neg(), netScyOut.Int());
    }

    /**
    * @notice swap SCY to exact YT with the help of flashswaps & YT tokenization / redemption
    * @dev inner working of this function:
     - `market.swapExactPtForScy` is called, which will transfer SCY directly to YT contract & callback is invoked.
        Note that now we owe PT
     - in callback, we will pull in more SCY as needed & mint all SCY to PT + YT. PT is then used to payback the loan
        while YT is transferred to the user
    * @dev this function works in conjunction with ActionCallback
     */
    function swapScyForExactYt(
        address receiver,
        address market,
        uint256 exactYtOut,
        uint256 maxScyIn
    ) external returns (uint256 netScyIn, uint256 netScyFee) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 preScyBalance = SCY.balanceOf(msg.sender);

        (, netScyFee) = IPMarket(market).swapExactPtForScy(
            address(YT),
            exactYtOut, // exactPtIn = exactYtOut
            _encodeSwapScyForExactYt(msg.sender, receiver, maxScyIn)
        );

        netScyIn = preScyBalance - SCY.balanceOf(msg.sender);

        emit SwapYtAndScy(msg.sender, market, receiver, exactYtOut.Int(), netScyIn.neg());
    }

    /**
    * @notice swap YT to exact SCY with the help of flashswaps & YT tokenization / redemption
    * @dev inner working of this function:
     - transfer netYtIn (received from approx function) to YT contract
     - `market.swapScyForExactPt` is called, which will transfer PT directly to YT contract & callback is invoked.
        Note that now we owe SCY
     - in callback, we will redeem all PT + YT to get SCY. A portion of it is used to payback the loan. The rest is
        transferred to `receiver`
    * @dev this function works in conjunction with ActionCallback
     */
    function swapYtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        uint256 maxYtIn,
        ApproxParams memory guessYtIn
    ) external returns (uint256 netYtIn, uint256 netScyFee) {
        MarketState memory state = IPMarket(market).readState();
        (, , IPYieldToken YT) = IPMarket(market).readTokens();

        (netYtIn, , ) = state.approxSwapYtForExactScy(
            YT.newIndex(),
            exactScyOut,
            block.timestamp,
            guessYtIn
        );

        if (netYtIn > maxYtIn) revert Errors.RouterExceededLimitYtIn(netYtIn, maxYtIn);

        YT.safeTransferFrom(msg.sender, address(YT), netYtIn);

        (, netScyFee) = IPMarket(market).swapScyForExactPt(
            address(YT),
            netYtIn, // exactPtOut = netYtIn
            _encodeSwapYtForScy(receiver, exactScyOut)
        );

        emit SwapYtAndScy(msg.sender, market, receiver, netYtIn.neg(), exactScyOut.Int());
    }

    function swapExactTokenForYt(
        address receiver,
        address market,
        uint256 minYtOut,
        ApproxParams memory guessYtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netYtOut, uint256 netScyFee) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 netScyUsedToBuyYT = _mintScyFromToken(address(YT), address(SCY), 1, input);

        (netYtOut, netScyFee) = _swapExactScyForYt(
            receiver,
            market,
            YT,
            netScyUsedToBuyYT,
            minYtOut,
            guessYtOut
        );

        emit SwapYtAndToken(
            msg.sender,
            market,
            receiver,
            input.tokenIn,
            netYtOut.Int(),
            input.netTokenIn.neg()
        );
    }

    function swapExactYtForToken(
        address receiver,
        address market,
        uint256 netYtIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netScyFee) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        YT.safeTransferFrom(msg.sender, address(YT), netYtIn);

        uint256 netScyOut;

        (netScyOut, netScyFee) = _swapExactYtForScy(address(SCY), market, SCY, YT, netYtIn, 1);

        netTokenOut = _redeemScyToToken(receiver, address(SCY), netScyOut, output, false);

        emit SwapYtAndToken(
            msg.sender,
            market,
            receiver,
            output.tokenOut,
            netYtIn.neg(),
            netTokenOut.Int()
        );
    }

    function _swapExactScyForYt(
        address receiver,
        address market,
        IPYieldToken YT,
        uint256 exactScyIn,
        uint256 minYtOut,
        ApproxParams memory guessYtOut
    ) internal returns (uint256 netYtOut, uint256 netScyFee) {
        MarketState memory state = IPMarket(market).readState();

        (netYtOut, ) = state.approxSwapExactScyForYt(
            YT.newIndex(),
            exactScyIn,
            block.timestamp,
            guessYtOut
        );

        // early-check
        if (netYtOut < minYtOut) revert Errors.RouterInsufficientYtOut(netYtOut, minYtOut);

        (, netScyFee) = IPMarket(market).swapExactPtForScy(
            address(YT),
            netYtOut, // exactPtIn = netYtOut
            _encodeSwapExactScyForYt(receiver, minYtOut)
        );
    }

    function _swapExactYtForScy(
        address receiver,
        address market,
        ISuperComposableYield SCY,
        IPYieldToken YT,
        uint256 exactYtIn,
        uint256 minScyOut
    ) internal returns (uint256 netScyOut, uint256 netScyFee) {
        uint256 preScyBalance = SCY.balanceOf(receiver);

        (, netScyFee) = IPMarket(market).swapScyForExactPt(
            address(YT),
            exactYtIn, // exactPtOut = exactYtIn
            _encodeSwapYtForScy(receiver, minScyOut)
        ); // ignore return

        netScyOut = SCY.balanceOf(receiver) - preScyBalance;
    }
}
