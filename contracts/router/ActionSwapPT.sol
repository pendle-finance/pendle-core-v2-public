// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./base/ActionBaseMintRedeem.sol";
import "../interfaces/IPActionSwapPT.sol";
import "../interfaces/IPMarket.sol";
import "../core/libraries/Errors.sol";

contract ActionSwapPT is IPActionSwapPT, ActionBaseMintRedeem {
    using MarketMathCore for MarketState;
    using MarketApproxPtInLib for MarketState;
    using MarketApproxPtOutLib for MarketState;
    using Math for uint256;
    using Math for int256;
    using SafeERC20 for IERC20;
    using PYIndexLib for IPYieldToken;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter, address _bulkSellerDirectory)
        ActionBaseMintRedeem(_kyberSwapRouter, _bulkSellerDirectory) //solhint-disable-next-line no-empty-blocks
    {}

    function swapExactPtForSy(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minSyOut
    ) external returns (uint256 netSyOut, uint256 netSyFee) {
        (, IPPrincipalToken PT, ) = IPMarket(market).readTokens();
        IERC20(address(PT)).safeTransferFrom(msg.sender, market, exactPtIn);

        (netSyOut, netSyFee) = IPMarket(market).swapExactPtForSy(receiver, exactPtIn, EMPTY_BYTES);

        if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut);

        emit SwapPtAndSy(msg.sender, market, receiver, exactPtIn.neg(), netSyOut.Int());
    }

    /**
     * @notice Note that the amount of SY out will be a bit more than `exactSyOut`, since an approximation is used. It's
        guaranteed that the `netSyOut` is at least `exactSyOut`
     */
    function swapPtForExactSy(
        address receiver,
        address market,
        uint256 exactSyOut,
        uint256 maxPtIn,
        ApproxParams calldata guessPtIn
    ) external returns (uint256 netPtIn, uint256 netSyFee) {
        MarketState memory state = IPMarket(market).readState();
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();

        (netPtIn, , ) = state.approxSwapPtForExactSy(
            YT.newIndex(),
            exactSyOut,
            block.timestamp,
            guessPtIn
        );

        if (netPtIn > maxPtIn) revert Errors.RouterExceededLimitPtIn(netPtIn, maxPtIn);

        IERC20(PT).safeTransferFrom(msg.sender, market, netPtIn);

        uint256 netSyOut;
        (netSyOut, netSyFee) = IPMarket(market).swapExactPtForSy(receiver, netPtIn, EMPTY_BYTES);

        // fail-safe
        if (netSyOut < exactSyOut) assert(false);

        emit SwapPtAndSy(msg.sender, market, receiver, netPtIn.neg(), exactSyOut.Int());
    }

    function swapSyForExactPt(
        address receiver,
        address market,
        uint256 exactPtOut,
        uint256 maxSyIn
    ) external returns (uint256 netSyIn, uint256 netSyFee) {
        MarketState memory state = IPMarket(market).readState();
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        (netSyIn, ) = state.swapSyForExactPt(YT.newIndex(), exactPtOut, block.timestamp);

        if (netSyIn > maxSyIn) revert Errors.RouterExceededLimitSyIn(netSyIn, maxSyIn);

        IERC20(SY).safeTransferFrom(msg.sender, market, netSyIn);

        (, netSyFee) = IPMarket(market).swapSyForExactPt(receiver, exactPtOut, EMPTY_BYTES); // ignore return

        // no fail-safe since exactly netSyIn will go into the market
        emit SwapPtAndSy(msg.sender, market, receiver, exactPtOut.Int(), netSyIn.neg());
    }

    function swapExactSyForPt(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut
    ) external returns (uint256 netPtOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        IERC20(SY).safeTransferFrom(msg.sender, market, exactSyIn);

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
     * @notice swap from any ERC20 tokens, through Uniswap's forks, to get baseTokens to make SY, then swap
        from SY to PT
     * @dev simply a combination of _mintSyFromToken & _swapExactSyForPt
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
     * @notice swap from PT to SY, then redeem SY to baseToken & swap through Uniswap's forks to get tokenOut
     * @dev simply a combination of _swapExactPtForSy & _redeemSyToToken
     */
    function swapExactPtForToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netSyFee) {
        (IStandardizedYield SY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        IERC20(address(PT)).safeTransferFrom(msg.sender, market, exactPtIn);

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
        MarketState memory state = IPMarket(market).readState();

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
