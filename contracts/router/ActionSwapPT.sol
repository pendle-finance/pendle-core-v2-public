// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./base/ActionBaseMintRedeem.sol";
import "../interfaces/IPActionSwapPT.sol";
import "../interfaces/IPMarket.sol";
import "../core/libraries/Errors.sol";

/// @dev All swap actions will revert if market is expired
contract ActionSwapPT is IPActionSwapPT, ActionBaseMintRedeem {
    using MarketMathCore for MarketState;
    using MarketApproxPtInLib for MarketState;
    using MarketApproxPtOutLib for MarketState;
    using PMath for uint256;
    using PMath for int256;
    using PYIndexLib for IPYieldToken;

    /**
     * @notice swaps exact amount of PT for SY
     * @param exactPtIn will always consume this exact amount of PT for as much SY as possible
     * @return netSyOut amount SY output, will not be less than `minSyOut`
     * @return netSyFee amount SY fee incurred
     */
    function swapExactPtForSy(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minSyOut
    ) external returns (uint256 netSyOut, uint256 netSyFee) {
        (, IPPrincipalToken PT, ) = IPMarket(market).readTokens();
        _transferFrom(IERC20(PT), msg.sender, market, exactPtIn);

        (netSyOut, netSyFee) = IPMarket(market).swapExactPtForSy(receiver, exactPtIn, EMPTY_BYTES);

        if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut);

        emit SwapPtAndSy(msg.sender, market, receiver, exactPtIn.neg(), netSyOut.Int());
    }

    /**
     * @notice swaps some amount of PT for the desired SY amount
     * @param guessPtIn approximation data for input PT amount
     * @param exactSyOut will consume as little PT as possible for this much SY amount
     * @return netPtIn amount of PT used, will not be more than `maxPtIn`
     * @return netSyFee amount SY fee incurred
     * @dev the SY output might be slightly more than `exactSyOut` since an approximation is used.
     * It is guaranteed that exactSyOut <= actualSyOut <= exactSyOut*(100% + guessPtIn.eps)
     */
    function swapPtForExactSy(
        address receiver,
        address market,
        uint256 exactSyOut,
        uint256 maxPtIn,
        ApproxParams calldata guessPtIn
    ) external returns (uint256 netPtIn, uint256 netSyFee) {
        MarketState memory state = IPMarket(market).readState(address(this));
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();

        (netPtIn, , ) = state.approxSwapPtForExactSy(
            YT.newIndex(),
            exactSyOut,
            block.timestamp,
            guessPtIn
        );

        if (netPtIn > maxPtIn) revert Errors.RouterExceededLimitPtIn(netPtIn, maxPtIn);

        _transferFrom(IERC20(PT), msg.sender, market, netPtIn);

        uint256 netSyOut;
        (netSyOut, netSyFee) = IPMarket(market).swapExactPtForSy(receiver, netPtIn, EMPTY_BYTES);

        // fail-safe
        if (netSyOut < exactSyOut) assert(false);

        emit SwapPtAndSy(msg.sender, market, receiver, netPtIn.neg(), exactSyOut.Int());
    }

    /**
     * @notice swaps SY for exact amount of PT
     * @param exactPtOut will always consume as little SY as possible for this much amount of PT
     * @return netSyIn amount SY used, will not be more than `maxSyIn`
     * @return netSyFee amount SY fee incurred
     * @dev the output amount of PT here is exact, no approximation is used
     */
    function swapSyForExactPt(
        address receiver,
        address market,
        uint256 exactPtOut,
        uint256 maxSyIn
    ) external returns (uint256 netSyIn, uint256 netSyFee) {
        MarketState memory state = IPMarket(market).readState(address(this));
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        (netSyIn, , ) = state.swapSyForExactPt(YT.newIndex(), exactPtOut, block.timestamp);

        if (netSyIn > maxSyIn) revert Errors.RouterExceededLimitSyIn(netSyIn, maxSyIn);

        _transferFrom(IERC20(SY), msg.sender, market, netSyIn);

        (, netSyFee) = IPMarket(market).swapSyForExactPt(receiver, exactPtOut, EMPTY_BYTES); // ignore return

        // no fail-safe since exactly netSyIn will go into the market
        emit SwapPtAndSy(msg.sender, market, receiver, exactPtOut.Int(), netSyIn.neg());
    }

    /**
     * @notice swaps exact amount of SY for as much PT as possible
     * @param exactSyIn will always consume this much amount of SY
     * @param guessPtOut approximation data for output PT amount
     * @return netPtOut amount of PT output, will not be less than `minPtOut`
     * @return netSyFee amount SY fee incurred
     */
    function swapExactSyForPt(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut
    ) external returns (uint256 netPtOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        _transferFrom(IERC20(SY), msg.sender, market, exactSyIn);

        (netPtOut, netSyFee) = _swapExactSyForPt(
            receiver,
            market,
            YT,
            exactSyIn,
            minPtOut,
            guessPtOut
        );

        emit SwapPtAndSy(msg.sender, market, receiver, netPtOut.Int(), exactSyIn.neg());
    }

    /**
     * @notice swap (through Kyberswap) from any input token for SY-mintable tokens, then mints SY
     * and swaps said SY for PT
     * @param input data for input token, see {`./kyberswap/KyberSwapHelper.sol`}
     * @dev is a combination of `_mintSyFromToken()` and `_swapExactSyForPt()`
     */
    function swapExactTokenForPt(
        address receiver,
        address market,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netPtOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        // all output SY is transferred directly to the market
        uint256 netSyUseToBuyPt = _mintSyFromToken(address(market), address(SY), 1, input);

        // SY is already in the market, hence doPull = false
        (netPtOut, netSyFee) = _swapExactSyForPt(
            receiver,
            market,
            YT,
            netSyUseToBuyPt,
            minPtOut,
            guessPtOut
        );

        emit SwapPtAndToken(
            msg.sender,
            market,
            input.tokenIn,
            receiver,
            netPtOut.Int(),
            input.netTokenIn.neg()
        );
    }

    /**
     * @notice swap from exact amount of PT to SY, then redeem SY for assets, finally swaps
     * resulting assets through Kyberswap to get desired output token
     * @param exactPtIn will always consume this much PT for as much SY as possible
     * @param output data for desired output token, see {`./kyberswap/KyberSwapHelper.sol`}
     * @dev is a combination of `_swapExactPtForSy()` and `_redeemSyToToken()`
     */
    function swapExactPtForToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netSyFee) {
        (IStandardizedYield SY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        _transferFrom(IERC20(PT), msg.sender, market, exactPtIn);

        // all output SY is directly transferred to the SY contract
        uint256 netSyReceived;
        (netSyReceived, netSyFee) = IPMarket(market).swapExactPtForSy(
            _syOrBulk(address(SY), output),
            exactPtIn,
            EMPTY_BYTES
        );

        // since all SY is already at the SY contract, doPull = false
        netTokenOut = _redeemSyToToken(receiver, address(SY), netSyReceived, output, false);

        emit SwapPtAndToken(
            msg.sender,
            market,
            output.tokenOut,
            receiver,
            exactPtIn.neg(),
            netTokenOut.Int()
        );
    }

    function _swapExactSyForPt(
        address receiver,
        address market,
        IPYieldToken YT,
        uint256 exactSyIn,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut
    ) internal returns (uint256 netPtOut, uint256 netSyFee) {
        MarketState memory state = IPMarket(market).readState(address(this));

        (netPtOut, ) = state.approxSwapExactSyForPt(
            YT.newIndex(),
            exactSyIn,
            block.timestamp,
            guessPtOut
        );

        if (netPtOut < minPtOut) revert Errors.RouterInsufficientPtOut(netPtOut, minPtOut);

        (, netSyFee) = IPMarket(market).swapSyForExactPt(receiver, netPtOut, EMPTY_BYTES);
        // no fail-safe since exactly netPtOut >= minPtOut will be out
    }
}
