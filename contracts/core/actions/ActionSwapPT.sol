// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./base/ActionBaseMintRedeem.sol";
import "../../interfaces/IPActionSwapPT.sol";
import "../../interfaces/IPMarket.sol";

contract ActionSwapPT is IPActionSwapPT, ActionBaseMintRedeem {
    using MarketMathCore for MarketState;
    using MarketApproxPtInLib for MarketState;
    using MarketApproxPtOutLib for MarketState;
    using Math for uint256;
    using Math for int256;
    using SafeERC20 for IERC20;
    using PYIndexLib for IPYieldToken;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter)
        ActionBaseMintRedeem(_kyberSwapRouter) //solhint-disable-next-line no-empty-blocks
    {}

    function swapExactPtForScy(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minScyOut
    ) external returns (uint256 netScyOut, uint256 netScyFee) {
        (, IPPrincipalToken PT, ) = IPMarket(market).readTokens();
        IERC20(address(PT)).safeTransferFrom(msg.sender, market, exactPtIn);

        (netScyOut, netScyFee) = IPMarket(market).swapExactPtForScy(
            receiver,
            exactPtIn,
            EMPTY_BYTES
        );

        require(netScyOut >= minScyOut, "insufficient SCY out");

        emit SwapPtAndScy(msg.sender, market, receiver, exactPtIn.neg(), netScyOut.Int());
    }

    /**
     * @notice Note that the amount of SCY out will be a bit more than `exactScyOut`, since an approximation is used. It's
        guaranteed that the `netScyOut` is at least `exactScyOut`
     */
    function swapPtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        uint256 maxPtIn,
        ApproxParams calldata guessPtIn
    ) external returns (uint256 netPtIn, uint256 netScyFee) {
        MarketState memory state = IPMarket(market).readState();
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();

        (netPtIn, , ) = state.approxSwapPtForExactScy(
            YT.newIndex(),
            exactScyOut,
            block.timestamp,
            guessPtIn
        );
        require(netPtIn <= maxPtIn, "exceed limit PT in");

        IERC20(PT).safeTransferFrom(msg.sender, market, netPtIn);

        uint256 netScyOut;
        (netScyOut, netScyFee) = IPMarket(market).swapExactPtForScy(
            receiver,
            netPtIn,
            EMPTY_BYTES
        );

        // fail-safe
        require(netScyOut >= exactScyOut, "FS insufficient SCY out");

        emit SwapPtAndScy(msg.sender, market, receiver, netPtIn.neg(), exactScyOut.Int());
    }

    function swapScyForExactPt(
        address receiver,
        address market,
        uint256 exactPtOut,
        uint256 maxScyIn
    ) external returns (uint256 netScyIn, uint256 netScyFee) {
        MarketState memory state = IPMarket(market).readState();
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        (netScyIn, ) = state.swapScyForExactPt(YT.newIndex(), exactPtOut, block.timestamp);

        require(netScyIn <= maxScyIn, "exceed limit SCY in");

        IERC20(SCY).safeTransferFrom(msg.sender, market, netScyIn);

        (, netScyFee) = IPMarket(market).swapScyForExactPt(receiver, exactPtOut, EMPTY_BYTES); // ignore return

        // no fail-safe since exactly netScyIn will go into the market
        emit SwapPtAndScy(msg.sender, market, receiver, exactPtOut.Int(), netScyIn.neg());
    }

    function swapExactScyForPt(
        address receiver,
        address market,
        uint256 exactScyIn,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut
    ) external returns (uint256 netPtOut, uint256 netScyFee) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        IERC20(SCY).safeTransferFrom(msg.sender, market, exactScyIn);

        (netPtOut, netScyFee) = _swapExactScyForPt(
            receiver,
            market,
            YT,
            exactScyIn,
            minPtOut,
            guessPtOut
        );

        emit SwapPtAndScy(msg.sender, market, receiver, netPtOut.Int(), exactScyIn.neg());
    }

    /**
     * @notice swap from any ERC20 tokens, through Uniswap's forks, to get baseTokens to make SCY, then swap
        from SCY to PT
     * @dev simply a combination of _mintScyFromToken & _swapExactScyForPt
     */
    function swapExactTokenForPt(
        address receiver,
        address market,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netPtOut, uint256 netScyFee) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        // all output SCY is transferred directly to the market
        uint256 netScyUseToBuyPt = _mintScyFromToken(address(market), address(SCY), 1, input);

        // SCY is already in the market, hence doPull = false
        (netPtOut, netScyFee) = _swapExactScyForPt(
            receiver,
            market,
            YT,
            netScyUseToBuyPt,
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
     * @notice swap from PT to SCY, then redeem SCY to baseToken & swap through Uniswap's forks to get tokenOut
     * @dev simply a combination of _swapExactPtForScy & _redeemScyToToken
     */
    function swapExactPtForToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netScyFee) {
        (ISuperComposableYield SCY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        IERC20(address(PT)).safeTransferFrom(msg.sender, market, exactPtIn);

        // all output SCY is directly transferred to the SCY contract
        uint256 netScyReceived;
        (netScyReceived, netScyFee) = IPMarket(market).swapExactPtForScy(
            address(SCY),
            exactPtIn,
            EMPTY_BYTES
        );

        // since all SCY is already at the SCY contract, doPull = false
        netTokenOut = _redeemScyToToken(receiver, address(SCY), netScyReceived, output, false);

        emit SwapPtAndToken(
            msg.sender,
            market,
            output.tokenOut,
            receiver,
            exactPtIn.neg(),
            netTokenOut.Int()
        );
    }

    function _swapExactScyForPt(
        address receiver,
        address market,
        IPYieldToken YT,
        uint256 exactScyIn,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut
    ) internal returns (uint256 netPtOut, uint256 netScyFee) {
        MarketState memory state = IPMarket(market).readState();

        (netPtOut, , ) = state.approxSwapExactScyForPt(
            YT.newIndex(),
            exactScyIn,
            block.timestamp,
            guessPtOut
        );

        require(netPtOut >= minPtOut, "insufficient PT out");

        (, netScyFee) = IPMarket(market).swapScyForExactPt(receiver, netPtOut, EMPTY_BYTES);
        // no fail-safe since exactly netPtOut >= minPtOut will be out
    }
}
