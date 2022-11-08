// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./base/ActionBaseMintRedeem.sol";
import "./base/CallbackHelper.sol";
import "../interfaces/IPActionSwapYT.sol";
import "../interfaces/IPMarket.sol";
import "../core/libraries/Errors.sol";

contract ActionSwapYT is IPActionSwapYT, ActionBaseMintRedeem, CallbackHelper {
    using Math for uint256;
    using Math for int256;
    using MarketMathCore for MarketState;
    using MarketApproxPtInLib for MarketState;
    using MarketApproxPtOutLib for MarketState;
    using PYIndexLib for IPYieldToken;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberScalingLib)
        ActionBaseMintRedeem(_kyberScalingLib) //solhint-disable-next-line no-empty-blocks
    {}

    /**
    * @notice swap exact SY to YT with the help of flashswaps & YT tokenization / redemption
    * @dev inner working of this function:
     - `exactSyIn` SY is transferred to YT contract
     - `market.swapExactPtForSy` is called, which will transfer SY directly to YT contract & callback is invoked.
        Note that now we owe PT
     - in callback, all SY in YT contract is used to mint PT + YT, with PT used to pay back the loan, and YT
        transferred to the receiver
    * @dev this function works in conjunction with ActionCallback
     */
    function swapExactSyForYt(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minYtOut,
        ApproxParams memory guessYtOut
    ) external returns (uint256 netYtOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        _transferFrom(IERC20(SY), msg.sender, address(YT), exactSyIn);

        (netYtOut, netSyFee) = _swapExactSyForYt(
            receiver,
            market,
            YT,
            exactSyIn,
            minYtOut,
            guessYtOut
        );

        emit SwapYtAndSy(msg.sender, market, receiver, netYtOut.Int(), exactSyIn.neg());
    }

    /**
    * @notice swap exact YT to SY with the help of flashswaps & YT tokenization / redemption
    * @dev inner working of this function:
     - `exactYtIn` YT is transferred to YT contract
     - `market.swapSyForExactPt` is called, which will transfer PT directly to YT contract & callback is invoked.
        Note that now we owe SY
     - in callback, all PT + YT in YT contract is used to redeem SY. A portion of SY is used to payback the loan,
        the rest is transferred to the `receiver`
    * @dev this function works in conjunction with ActionCallback
     */
    function swapExactYtForSy(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minSyOut
    ) external returns (uint256 netSyOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        _transferFrom(IERC20(YT), msg.sender, address(YT), exactYtIn);

        (netSyOut, netSyFee) = _swapExactYtForSy(receiver, market, SY, YT, exactYtIn, minSyOut);

        emit SwapYtAndSy(msg.sender, market, receiver, exactYtIn.neg(), netSyOut.Int());
    }

    /**
    * @notice swap SY to exact YT with the help of flashswaps & YT tokenization / redemption
    * @dev inner working of this function:
     - `market.swapExactPtForSy` is called, which will transfer SY directly to YT contract & callback is invoked.
        Note that now we owe PT
     - in callback, we will pull in more SY as needed & mint all SY to PT + YT. PT is then used to payback the loan
        while YT is transferred to the user
    * @dev this function works in conjunction with ActionCallback
     */
    function swapSyForExactYt(
        address receiver,
        address market,
        uint256 exactYtOut,
        uint256 maxSyIn
    ) external returns (uint256 netSyIn, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 preSyBalance = SY.balanceOf(msg.sender);

        (, netSyFee) = IPMarket(market).swapExactPtForSy(
            address(YT),
            exactYtOut, // exactPtIn = exactYtOut
            _encodeSwapSyForExactYt(msg.sender, receiver, maxSyIn)
        );

        netSyIn = preSyBalance - SY.balanceOf(msg.sender);

        emit SwapYtAndSy(msg.sender, market, receiver, exactYtOut.Int(), netSyIn.neg());
    }

    /**
    * @notice swap YT to exact SY with the help of flashswaps & YT tokenization / redemption
    * @dev inner working of this function:
     - transfer netYtIn (received from approx function) to YT contract
     - `market.swapSyForExactPt` is called, which will transfer PT directly to YT contract & callback is invoked.
        Note that now we owe SY
     - in callback, we will redeem all PT + YT to get SY. A portion of it is used to payback the loan. The rest is
        transferred to `receiver`
    * @dev this function works in conjunction with ActionCallback
     */
    function swapYtForExactSy(
        address receiver,
        address market,
        uint256 exactSyOut,
        uint256 maxYtIn,
        ApproxParams memory guessYtIn
    ) external returns (uint256 netYtIn, uint256 netSyFee) {
        MarketState memory state = IPMarket(market).readState(address(this));
        (, , IPYieldToken YT) = IPMarket(market).readTokens();

        (netYtIn, , ) = state.approxSwapYtForExactSy(
            YT.newIndex(),
            exactSyOut,
            block.timestamp,
            guessYtIn
        );

        if (netYtIn > maxYtIn) revert Errors.RouterExceededLimitYtIn(netYtIn, maxYtIn);

        _transferFrom(IERC20(YT), msg.sender, address(YT), netYtIn);

        (, netSyFee) = IPMarket(market).swapSyForExactPt(
            address(YT),
            netYtIn, // exactPtOut = netYtIn
            _encodeSwapYtForSy(receiver, exactSyOut)
        );

        emit SwapYtAndSy(msg.sender, market, receiver, netYtIn.neg(), exactSyOut.Int());
    }

    function swapExactTokenForYt(
        address receiver,
        address market,
        uint256 minYtOut,
        ApproxParams memory guessYtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netYtOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 netSyUsedToBuyYT = _mintSyFromToken(address(YT), address(SY), 1, input);

        (netYtOut, netSyFee) = _swapExactSyForYt(
            receiver,
            market,
            YT,
            netSyUsedToBuyYT,
            minYtOut,
            guessYtOut
        );

        emit SwapYtAndToken(
            msg.sender,
            market,
            input.tokenIn,
            receiver,
            netYtOut.Int(),
            input.netTokenIn.neg()
        );
    }

    function swapExactYtForToken(
        address receiver,
        address market,
        uint256 netYtIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        _transferFrom(IERC20(YT), msg.sender, address(YT), netYtIn);

        uint256 netSyOut;

        (netSyOut, netSyFee) = _swapExactYtForSy(
            _syOrBulk(address(SY), output),
            market,
            SY,
            YT,
            netYtIn,
            1
        );

        netTokenOut = _redeemSyToToken(receiver, address(SY), netSyOut, output, false);

        emit SwapYtAndToken(
            msg.sender,
            market,
            output.tokenOut,
            receiver,
            netYtIn.neg(),
            netTokenOut.Int()
        );
    }

    function _swapExactSyForYt(
        address receiver,
        address market,
        IPYieldToken YT,
        uint256 exactSyIn,
        uint256 minYtOut,
        ApproxParams memory guessYtOut
    ) internal returns (uint256 netYtOut, uint256 netSyFee) {
        MarketState memory state = IPMarket(market).readState(address(this));

        (netYtOut, ) = state.approxSwapExactSyForYt(
            YT.newIndex(),
            exactSyIn,
            block.timestamp,
            guessYtOut
        );

        // early-check
        if (netYtOut < minYtOut) revert Errors.RouterInsufficientYtOut(netYtOut, minYtOut);

        (, netSyFee) = IPMarket(market).swapExactPtForSy(
            address(YT),
            netYtOut, // exactPtIn = netYtOut
            _encodeSwapExactSyForYt(receiver, minYtOut)
        );
    }

    function _swapExactYtForSy(
        address receiver,
        address market,
        IStandardizedYield SY,
        IPYieldToken YT,
        uint256 exactYtIn,
        uint256 minSyOut
    ) internal returns (uint256 netSyOut, uint256 netSyFee) {
        uint256 preSyBalance = SY.balanceOf(receiver);

        (, netSyFee) = IPMarket(market).swapSyForExactPt(
            address(YT),
            exactYtIn, // exactPtOut = exactYtIn
            _encodeSwapYtForSy(receiver, minSyOut)
        );

        netSyOut = SY.balanceOf(receiver) - preSyBalance;
    }
}
