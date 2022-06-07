// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../../interfaces/IPMarketFactory.sol";
import "../../../interfaces/IPMarket.sol";
import "../../../libraries/SCYUtils.sol";
import "../../../libraries/math/MarketApproxLib.sol";
import "./ActionSCYAndPYBase.sol";
import "./ActionType.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract ActionSCYAndYTBase is ActionSCYAndPYBase, ActionType {
    using Math for uint256;
    using Math for int256;
    using MarketMathCore for MarketState;
    using MarketApproxLib for MarketState;
    using SafeERC20 for ISuperComposableYield;
    using SafeERC20 for IPYieldToken;
    using SCYIndexLib for ISuperComposableYield;

    event SwapYTAndSCY(address indexed user, int256 ytToAccount, int256 scyToAccount);

    function _swapExactScyForYt(
        address receiver,
        address market,
        uint256 exactScyIn,
        uint256 minYtOut,
        ApproxParams memory approx,
        bool doPull
    ) internal returns (uint256 netYtOut) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();
        MarketState memory state = IPMarket(market).readState(false);

        (netYtOut, ) = state.approxSwapExactScyForYt(
            SCY.newIndex(),
            exactScyIn,
            block.timestamp,
            approx
        );

        // early-check
        require(netYtOut >= minYtOut, "insufficient YT out");

        if (doPull) {
            SCY.safeTransferFrom(msg.sender, address(YT), exactScyIn);
        }

        IPMarket(market).swapExactPtForScy(
            address(YT),
            netYtOut, // exactPtIn = netYtOut
            abi.encode(ACTION_TYPE.SwapExactScyForYt, receiver, minYtOut)
        );

        emit SwapYTAndSCY(receiver, netYtOut.Int(), exactScyIn.neg());
    }

    /**
    * @dev inner working of this function:
     - YT is transferred to the YT contract
     - market.swap is called, which will transfer PT directly to the YT contract, and callback is invoked
     - callback will call YT's redeemPY, which will redeem the outcome SCY to this router, then
        all SCY owed to the market will be paid, the rest is transferred to the receiver
     */
    function _swapExactYtForScy(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minScyOut,
        bool doPull
    ) internal returns (uint256 netScyOut) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        if (doPull) {
            YT.safeTransferFrom(msg.sender, address(YT), exactYtIn);
        }

        uint256 preScyBalance = SCY.balanceOf(receiver);

        IPMarket(market).swapScyForExactPt(
            address(YT),
            exactYtIn, // exactPtOut = exactYtIn
            abi.encode(ACTION_TYPE.SwapExactYtForScy, receiver, minScyOut)
        ); // ignore return

        // no check in callback because
        netScyOut = SCY.balanceOf(receiver) - preScyBalance;
        require(netScyOut >= minScyOut, "insufficient SCY out");

        emit SwapYTAndSCY(receiver, exactYtIn.neg(), netScyOut.Int());
    }

    /**
     * @dev inner working of this function:
     - market.swap is called, which will transfer SCY directly to the YT contract, and callback is invoked
     - callback will pull more SCY if necessary, do call YT's mintPY, which will mint PT to the market & YT to the receiver
     */
    function _swapScyForExactYt(
        address receiver,
        address market,
        uint256 exactYtOut,
        uint256 maxScyIn
    ) internal returns (uint256 netScyIn) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();

        IPMarket(market).swapExactPtForScy(
            address(YT),
            exactYtOut, // exactPtIn = exactYtOut
            abi.encode(ACTION_TYPE.SwapSCYForExactYt, msg.sender, receiver, maxScyIn)
        );

        emit SwapYTAndSCY(receiver, exactYtOut.Int(), netScyIn.neg());
    }

    function _swapYtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        uint256 maxYtIn,
        ApproxParams memory approx,
        bool doPull
    ) internal returns (uint256 netYtIn) {
        MarketState memory state = IPMarket(market).readState(false);
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        (netYtIn, ) = state.approxSwapYtForExactScy(
            SCY.newIndex(),
            exactScyOut,
            block.timestamp,
            approx
        );

        require(netYtIn <= maxYtIn, "exceed YT in limit");

        if (doPull) {
            YT.safeTransferFrom(msg.sender, address(YT), netYtIn);
        }

        IPMarket(market).swapScyForExactPt(
            address(YT),
            netYtIn, // exactPtOut = netYtIn
            abi.encode(ACTION_TYPE.SwapYtForExactScy, receiver, exactScyOut)
        ); // ignore return

        emit SwapYTAndSCY(receiver, netYtIn.neg(), exactScyOut.Int());
    }

    /**
     * @dev netYtOutGuessMin & Max can be used in the same way as RawTokenPT
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
     * @dev inner working of this function:
     - mintScyFromRawToken is invoked, except the YT contract will receive all the outcome SCY
     - market.swapExactPtToScy is called, which will transfer SCY to the YT contract, and callback is invoked
     - callback will do call YT.mintPT, which will mint PT to the market & YT to the receiver
     * @param approx params to approx. Guess params will be the min, max & offchain guess for netYtOut
     */
    function _swapExactRawTokenForYt(
        address receiver,
        address market,
        uint256 exactRawTokenIn,
        uint256 minYtOut,
        address[] calldata path,
        ApproxParams memory approx,
        bool doPull
    ) internal returns (uint256 netYtOut) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 netScyUsedToBuyYT = _mintScyFromRawToken(
            exactRawTokenIn,
            address(SCY),
            1,
            address(YT),
            path,
            doPull
        );

        netYtOut = _swapExactScyForYt(
            receiver,
            market,
            netScyUsedToBuyYT,
            minYtOut,
            approx,
            false
        );
    }

    /**
     * @notice swap YT -> SCY -> baseToken -> rawToken
     * @notice the algorithm to swap will guarantee to swap all the YT available
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
     * @dev inner working of this function:
     - YT is transferred to the YT contract
     - market.swapScyForExactPt is called, which will transfer PT directly to the YT contract, and callback is invoked
     - callback will do call YT.redeemPY, which will redeem the outcome SCY to this router, then
        all SCY owed to the market will be paid, the rest is used to feed redeemScyToRawToken
     */
    function _swapExactYtForRawToken(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minRawTokenOut,
        address[] calldata path,
        bool doPull
    ) internal returns (uint256 netRawTokenOut) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        uint256 netScyOut = _swapExactYtForScy(address(SCY), market, exactYtIn, 1, doPull);

        netRawTokenOut = _redeemScyToRawToken(
            address(SCY),
            netScyOut,
            minRawTokenOut,
            receiver,
            path,
            false
        );
    }
}
