// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.14;

import "../../../interfaces/IPMarketFactory.sol";
import "../../../interfaces/IPMarket.sol";
import "../../../libraries/SCYIndex.sol";
import "../../../libraries/math/MarketApproxLib.sol";
import "../../../libraries/math/MarketMathAux.sol";
import "./ActionSCYAndPYBase.sol";
import "./ActionType.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract ActionPTAndYTBase is ActionType {
    using Math for uint256;
    using Math for int256;
    using MarketMathCore for MarketState;
    using MarketMathAux for MarketState;
    using MarketApproxLib for MarketState;
    using SafeERC20 for ISuperComposableYield;
    using SafeERC20 for IPYieldToken;
    using SafeERC20 for IPPrincipalToken;

    struct SwapPTAndYTData {
        address receiver;
        address market;
        ApproxParams approx;
        bool doPull;
    }

    function _swapExactPtForYt(SwapPTAndYTData memory data, uint256 exactPtIn)
        internal
        returns (uint256)
    {
        (ISuperComposableYield SCY, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(data.market)
            .readTokens();
        MarketState memory state = IPMarket(data.market).readState(false);

        (uint256 netPtIn, uint256 netYtOut) = state.approxSwapExactPtToYt(
            SCYIndexLib.newIndex(SCY),
            exactPtIn,
            block.timestamp,
            data.approx
        );

        if (data.doPull) {
            PT.safeTransferFrom(msg.sender, data.market, netPtIn);
        }

        IPMarket(data.market).swapExactPtForScy(
            address(YT),
            netPtIn + netYtOut,
            1,
            abi.encode(ACTION_TYPE.SwapPtForYt, data.receiver)
        );
        return netYtOut;
    }

    function _swapPtForExactYt(SwapPTAndYTData memory data, uint256 minYtOut)
        internal
        returns (uint256)
    {
        (ISuperComposableYield SCY, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(data.market)
            .readTokens();
        MarketState memory state = IPMarket(data.market).readState(false);

        (uint256 netPtIn, uint256 netYtOut) = state.approxSwapPtToExactYt(
            SCYIndexLib.newIndex(SCY),
            minYtOut,
            block.timestamp,
            data.approx
        );

        if (data.doPull) {
            PT.safeTransferFrom(msg.sender, data.market, netPtIn);
        }

        IPMarket(data.market).swapExactPtForScy(
            address(YT),
            netPtIn + netYtOut,
            1,
            abi.encode(ACTION_TYPE.SwapPtForYt, data.receiver)
        );
        return netPtIn;
    }

    function _swapYtForExactPt(SwapPTAndYTData memory data, uint256 exactPtOut)
        internal
        returns (uint256)
    {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(data.market).readTokens();
        MarketState memory state = IPMarket(data.market).readState(false);

        (uint256 netYtIn, uint256 netPtOut) = state.approxSwapYtToExactPt(
            SCYIndexLib.newIndex(SCY),
            exactPtOut,
            block.timestamp,
            data.approx
        );

        if (data.doPull) {
            YT.safeTransferFrom(msg.sender, address(YT), netYtIn);
        }

        IPMarket(data.market).swapScyForExactPt(
            address(this),
            netYtIn + netPtOut,
            type(uint256).max,
            abi.encode(ACTION_TYPE.SwapYtForPt, data.receiver)
        );
        return netYtIn;
    }

    function _swapExactYtForPt(SwapPTAndYTData memory data, uint256 exactYTIn)
        internal
        returns (uint256)
    {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(data.market).readTokens();
        MarketState memory state = IPMarket(data.market).readState(false);

        (uint256 netYtIn, uint256 netPtOut) = state.approxSwapExactYtToPt(
            SCYIndexLib.newIndex(SCY),
            exactYTIn,
            block.timestamp,
            data.approx
        );

        if (data.doPull) {
            YT.safeTransferFrom(msg.sender, address(YT), netYtIn);
        }

        IPMarket(data.market).swapScyForExactPt(
            address(this),
            netYtIn + netPtOut,
            type(uint256).max,
            abi.encode(ACTION_TYPE.SwapYtForPt, data.receiver)
        );
        return netPtOut;
    }
}
