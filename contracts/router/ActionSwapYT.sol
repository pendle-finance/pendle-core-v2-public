// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./base/ActionBaseMintRedeem.sol";
import "./base/CallbackHelper.sol";
import "../interfaces/IPActionSwapYT.sol";
import "../interfaces/IAddressProvider.sol";
import "../interfaces/IPMarket.sol";
import "../core/libraries/Errors.sol";

import "./base/ActionBaseCallback.sol";

/// @dev All swap actions will revert if market is expired
contract ActionSwapYT is ActionBaseCallback, IPActionSwapYT, ActionBaseMintRedeem {
    using PMath for uint256;
    using PMath for int256;
    using MarketMathCore for MarketState;
    using MarketApproxPtInLib for MarketState;
    using MarketApproxPtOutLib for MarketState;
    using PYIndexLib for IPYieldToken;

    constructor(
        IAddressProvider provider,
        uint256 providerId
    ) ActionBaseCallback(_getMarketFactory(provider, providerId)) {}

    function _getMarketFactory(
        IAddressProvider provider,
        uint256 providerId
    ) internal view returns (address) {
        return provider.get(providerId);
    }

    /**
     * @notice swap exact SY to YT with the help of flashswaps & YT tokenization / redemption
     * @dev inner working of this function:
     - `exactSyIn` SY is transferred to YT contract
     - `market.swapExactPtForSy` is called, which will transfer more SY directly to YT contract &
       callback is invoked. Note that now we owe PT
     - in callback, all SY in YT contract is used to mint PT + YT, with all PT used to pay back the
       loan, and all YT transferred to the receiver
     * @param exactSyIn will always consume this amount of SY for as much YT as possible
     * @param guessYtOut approximation data for total YT output
     * @dev this function works in conjunction with ActionCallback
     */
    function swapExactSyForYt(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minYtOut,
        ApproxParams calldata guessYtOut
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
     - `market.swapSyForExactPt` is called, which will transfer PT directly to YT contract &
       callback is invoked. Note that now we owe SY.
     - In callback, all PT + YT in YT contract is used to redeem SY. A portion of SY is used to
       payback the loan, the rest is transferred to the `receiver`
     * @param exactYtIn will consume exactly this much YT for as much SY as possible
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
     - `market.swapExactPtForSy` is called, which will transfer SY directly to YT contract &
       callback is invoked. Note that now we owe PT
     - In callback, we will pull in more SY as needed from caller & mint all SY to PT + YT. PT is
       then used to payback the loan, while YT is transferred to `receiver`
     * @param exactYtOut will output exactly this amount of YT, no approximation is used
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
            _encodeSwapSyForExactYt(msg.sender, receiver, maxSyIn, SY, YT)
        );

        netSyIn = preSyBalance - SY.balanceOf(msg.sender);

        emit SwapYtAndSy(msg.sender, market, receiver, exactYtOut.Int(), netSyIn.neg());
    }

    /**
     * @notice swap YT to exact SY with the help of flashswaps & YT tokenization / redemption
     * @dev inner working of this function:
     - Approximates `netYtIn` using the data from `guessYtIn`
     - Pulls `netYtIn` amount of YT from caller
     - `market.swapSyForExactPt` is called, which will transfer PT directly to YT contract &
       callback is invoked. Note that now we owe SY
     - In callback, we will redeem all PT + YT to get SY. A portion of it is used to payback the
       loan. The rest is transferred to `receiver`
     * @dev this function works in conjunction with ActionCallback
     */
    function swapYtForExactSy(
        address receiver,
        address market,
        uint256 exactSyOut,
        uint256 maxYtIn,
        ApproxParams calldata guessYtIn
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
            _encodeSwapYtForSy(receiver, exactSyOut, YT)
        );

        emit SwapYtAndSy(msg.sender, market, receiver, netYtIn.neg(), exactSyOut.Int());
    }

    /**
     * @notice swaps any token to YT
     * @dev this function swaps token for SY-mintable token first through Kyberswap, then mints SY
     * from such, finally swaps SY to YT (see `swapSyForExactYt()`)
     */
    function swapExactTokenForYt(
        address receiver,
        address market,
        uint256 minYtOut,
        ApproxParams calldata guessYtOut,
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

    /**
     * @notice swaps YT to a given token
     * @dev the function first swaps YT to SY (see `swapExactYtForSy()`), then redeems SY,
     * finally swaps resulting tokens to desired output token using Kyberswap
     */
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

    /**
     * @notice swap exact PT to YT with the help of flashswaps & YT tokenization / redemption
     * @dev inner working of this function:
     - `exactPtIn` PT is transferred to market contract
     - `market.swapExactPtForSy` is called, which will transfer SY directly to YT contract & callback is invoked.
        Note that we will owe PT, the amount before is not sufficient
     - in callback, all SY in YT contract is used to mint PT + YT, with PT used to pay the rest of the loan, and YT
        transferred to the receiver
     * @param exactPtIn will always consume this amount of PT for as much YT as possible
     * @param guessTotalPtToSwap approximation data for PT used for the PT-to-SY flashswap
     * @dev this function works in conjunction with ActionCallback
     */
    function swapExactPtForYt(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minYtOut,
        ApproxParams calldata guessTotalPtToSwap
    ) external returns (uint256 netYtOut, uint256 netSyFee) {
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();
        MarketState memory state = IPMarket(market).readState(address(this));

        _transferFrom(IERC20(PT), msg.sender, market, exactPtIn);

        uint256 totalPtToSwap;
        (netYtOut, totalPtToSwap, netSyFee) = state.approxSwapExactPtForYt(
            YT.newIndex(),
            exactPtIn,
            block.timestamp,
            guessTotalPtToSwap
        );

        if (netYtOut < minYtOut) revert Errors.RouterInsufficientYtOut(netYtOut, minYtOut);

        IPMarket(market).swapExactPtForSy(
            address(YT),
            totalPtToSwap,
            _encodeSwapExactPtForYt(receiver, exactPtIn, minYtOut, YT)
        );

        emit SwapPtAndYt(msg.sender, market, receiver, exactPtIn.neg(), netYtOut.Int());
    }

    /**
     * @notice swap exact YT to PT with the help of flashswaps & YT tokenization / redemption
     * @dev inner working of this function:
     - `exactYtIn` YT is transferred to yield contract
     - `market.swapSyForExactPt` is called, which will transfer PT directly to this contract & callback is invoked.
        Note that we now owe SY
     - in callback, a portion of PT + YT is used to redeem SY, which is then used to payback the loan. The rest of
       of the PT is transferred to `receiver`
     * @param exactYtIn will always consume this amount of YT for as much PT as possible
     * @param guessTotalPtFromSwap approximation data for PT output of the SY-to-PT flashswap
     * @dev this function works in conjunction with ActionCallback
     */
    function swapExactYtForPt(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minPtOut,
        ApproxParams calldata guessTotalPtFromSwap
    ) external returns (uint256 netPtOut, uint256 netSyFee) {
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();
        MarketState memory state = IPMarket(market).readState(address(this));

        _transferFrom(IERC20(YT), msg.sender, address(YT), exactYtIn);

        uint256 totalPtFromSwap;
        (netPtOut, totalPtFromSwap, netSyFee) = state.approxSwapExactYtForPt(
            YT.newIndex(),
            exactYtIn,
            block.timestamp,
            guessTotalPtFromSwap
        );

        if (netPtOut < minPtOut) revert Errors.RouterInsufficientPtOut(netPtOut, minPtOut);

        IPMarket(market).swapSyForExactPt(
            address(this),
            totalPtFromSwap,
            _encodeSwapExactYtForPt(receiver, exactYtIn, minPtOut, PT, YT)
        );

        emit SwapPtAndYt(msg.sender, market, receiver, netPtOut.Int(), exactYtIn.neg());
    }

    function _swapExactSyForYt(
        address receiver,
        address market,
        IPYieldToken YT,
        uint256 exactSyIn,
        uint256 minYtOut,
        ApproxParams calldata guessYtOut
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
            _encodeSwapExactSyForYt(receiver, minYtOut, YT)
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
            _encodeSwapYtForSy(receiver, minSyOut, YT)
        );

        netSyOut = SY.balanceOf(receiver) - preSyBalance;
    }
}
