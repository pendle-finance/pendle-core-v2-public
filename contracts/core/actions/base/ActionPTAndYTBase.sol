// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../../interfaces/IPMarketFactory.sol";
import "../../../interfaces/IPMarket.sol";
import "../../../SuperComposableYield/SCYUtils.sol";
import "../../../libraries/math/MarketApproxLib.sol";
import "../../../libraries/math/MarketMathAux.sol";
import "./ActionSCYAndPYBase.sol";
import "./ActionType.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract ActionPTAndYTBase is ActionSCYAndPYBase, ActionType {
    using Math for uint256;
    using Math for int256;
    using MarketMathCore for MarketState;
    using MarketMathAux for MarketState;
    using MarketApproxLib for MarketState;
    using SafeERC20 for ISuperComposableYield;
    using SafeERC20 for IPYieldToken;
    using SafeERC20 for IERC20;

    function _swapExactPTForYT(
        address receiver,
        address market,
        uint256 exactPtIn,
        ApproxParams memory approx,
        bool doPull
    ) internal returns (uint256) {
        (ISuperComposableYield SCY, IERC20 PT, IPYieldToken YT) = IPMarket(market).readTokens();
        MarketState memory state = IPMarket(market).readState(false);

        (uint256 netPtIn, uint256 netYtOut) = state.approxSwapExactPtToYt(
            SCYIndexLib.newIndex(SCY),
            exactPtIn,
            block.timestamp,
            approx
        );

        if (doPull) {
            PT.safeTransferFrom(msg.sender, market, netPtIn);
        }

        IPMarket(market).swapExactPtForScy(
            address(YT),
            netPtIn + netYtOut,
            1,
            abi.encode(ACTION_TYPE.SwapPtForYt, receiver)
        );
    }

    function _swapPTForExactYT(
        address receiver,
        address market,
        uint256 minYtOut,
        ApproxParams memory approx,
        bool doPull
    ) internal {
        (ISuperComposableYield SCY, IERC20 PT, IPYieldToken YT) = IPMarket(market).readTokens();
        MarketState memory state = IPMarket(market).readState(false);

        (uint256 netPtIn, uint256 netYtOut) = state.approxSwapPtToExactYt(
            SCYIndexLib.newIndex(SCY),
            minYtOut,
            block.timestamp,
            approx
        );

        if (doPull) {
            PT.safeTransferFrom(msg.sender, market, netPtIn);
        }

        IPMarket(market).swapExactPtForScy(
            address(YT),
            netPtIn + netYtOut,
            1,
            abi.encode(ACTION_TYPE.SwapPtForYt, receiver)
        );
    }

    function _swapYTForExactPt(
        address receiver,
        address market,
        uint256 exactPtOut,
        ApproxParams memory approx,
        bool doPull
    ) internal {
        (ISuperComposableYield SCY, IERC20 PT, IPYieldToken YT) = IPMarket(market).readTokens();
        MarketState memory state = IPMarket(market).readState(false);

        (uint256 netYtIn, uint256 netPtOut) = state.approxSwapYtToExactPt(
            SCYIndexLib.newIndex(SCY),
            exactPtOut,
            block.timestamp,
            approx
        );

        if (doPull) {
            YT.safeTransferFrom(msg.sender, address(YT), netYtIn);
        }

        IPMarket(market).swapScyForExactPt(
            address(this),
            netYtIn + netPtOut,
            type(uint256).max,
            abi.encode(ACTION_TYPE.SwapYtForPt, receiver)
        );
    }

    function _swapExactYTForPT(
        address receiver,
        address market,
        uint256 exactYTIn,
        ApproxParams memory approx,
        bool doPull
    ) internal {
        (ISuperComposableYield SCY, IERC20 PT, IPYieldToken YT) = IPMarket(market).readTokens();
        MarketState memory state = IPMarket(market).readState(false);

        (uint256 netYtIn, uint256 netPtOut) = state.approxSwapExactYtToPt(
            SCYIndexLib.newIndex(SCY),
            exactYTIn,
            block.timestamp,
            approx
        );

        if (doPull) {
            YT.safeTransferFrom(msg.sender, address(YT), netYtIn);
        }

        IPMarket(market).swapScyForExactPt(
            address(this),
            netYtIn + netPtOut,
            type(uint256).max,
            abi.encode(ACTION_TYPE.SwapYtForPt, receiver)
        );
    }
}
