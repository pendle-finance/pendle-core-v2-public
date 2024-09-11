// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IPMarket} from "../interfaces/IPMarket.sol";
import {IStandardizedYield} from "../interfaces/IStandardizedYield.sol";
import {IPPrincipalToken} from "../interfaces/IPPrincipalToken.sol";
import {IPActionSimple} from "../interfaces/IPActionSimple.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TokenHelper} from "../core/libraries/TokenHelper.sol";
import {PYIndexLib, IPYieldToken, PYIndex} from "../core/StandardizedYield/PYIndex.sol";
import {MarketState} from "../core/Market/MarketMathCore.sol";
import {PMath} from "../core/libraries/math/PMath.sol";

import {CallbackHelper} from "./base/CallbackHelper.sol";
import {MarketApproxPtInLibOnchain, MarketApproxPtOutLibOnchain} from "./math/MarketApproxLibOnchain.sol";
import {TokenInput, TokenOutput} from "../interfaces/IPAllActionTypeV3.sol";
import {ActionBase} from "./base/ActionBase.sol";

contract ActionSimple is ActionBase, IPActionSimple {
    using MarketApproxPtInLibOnchain for MarketState;
    using MarketApproxPtOutLibOnchain for MarketState;
    using PYIndexLib for IPYieldToken;
    using PYIndexLib for PYIndex;
    using PMath for uint256;

    // ------------------ SWAP TOKEN FOR PT ------------------
    function swapExactTokenForPtSimple(
        address receiver,
        address market,
        uint256 minPtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
        netSyInterm = _mintSyFromToken(address(this), address(SY), 1, input);

        (netPtOut, netSyFee) = _swapExactSyForPtSimple(receiver, market, netSyInterm, minPtOut);
        emit SwapPtAndToken(
            msg.sender,
            market,
            input.tokenIn,
            receiver,
            netPtOut.Int(),
            input.netTokenIn.neg(),
            netSyInterm
        );
    }

    function swapExactSyForPtSimple(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minPtOut
    ) external returns (uint256 netPtOut, uint256 netSyFee) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
        _transferFrom(SY, msg.sender, address(this), exactSyIn);

        (netPtOut, netSyFee) = _swapExactSyForPtSimple(receiver, market, exactSyIn, minPtOut);
        emit SwapPtAndSy(msg.sender, market, receiver, netPtOut.Int(), exactSyIn.neg());
    }

    function swapExactTokenForYtSimple(
        address receiver,
        address market,
        uint256 minYtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netYtOut, uint256 netSyFee, uint256 netSyInterm) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        netSyInterm = _mintSyFromToken(address(this), address(SY), 1, input);
        (netYtOut, netSyFee) = _swapExactSyForYtSimple(receiver, market, SY, YT, netSyInterm, minYtOut);

        emit SwapYtAndToken(
            msg.sender,
            market,
            input.tokenIn,
            receiver,
            netYtOut.Int(),
            input.netTokenIn.neg(),
            netSyInterm
        );
    }

    function swapExactSyForYtSimple(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minYtOut
    ) external returns (uint256 netYtOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();
        _transferFrom(SY, msg.sender, address(this), exactSyIn);

        (netYtOut, netSyFee) = _swapExactSyForYtSimple(receiver, market, SY, YT, exactSyIn, minYtOut);
        emit SwapYtAndSy(msg.sender, market, receiver, netYtOut.Int(), exactSyIn.neg());
    }

    function addLiquiditySinglePtSimple(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 minLpOut
    ) external returns (uint256 netLpOut, uint256 netSyFee) {
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();
        _transferFrom(PT, msg.sender, address(this), netPtIn);

        uint256 netPtLeft = netPtIn;
        uint256 netSyReceived;

        (uint256 netPtSwapMarket, , , ) = _readMarket(market).approxSwapPtToAddLiquidity(
            YT.newIndex(),
            netPtLeft,
            netSyReceived,
            block.timestamp
        );

        // execute the swap
        (uint256 netSyOutMarket, uint256 netSyFeeMarket) = IPMarket(market).swapExactPtForSy(
            market,
            netPtSwapMarket,
            EMPTY_BYTES
        );

        netPtLeft -= netPtSwapMarket;
        netSyReceived += netSyOutMarket;
        netSyFee += netSyFeeMarket;

        // execute the addLiquidity
        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyReceived, netPtLeft);

        if (netLpOut < minLpOut) revert("Slippage: INSUFFICIENT_LP_OUT");

        emit AddLiquiditySinglePt(msg.sender, market, receiver, netPtIn, netLpOut);
    }

    // ------------------ ADD LIQUIDITY SINGLE TOKEN ------------------

    function addLiquiditySingleTokenSimple(
        address receiver,
        address market,
        uint256 minLpOut,
        TokenInput calldata input
    ) external payable returns (uint256 netLpOut, uint256 netSyFee, uint256 netSyInterm) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        netSyInterm = _mintSyFromToken(address(this), address(SY), 1, input);

        (netLpOut, netSyFee) = _addLiquiditySingleSySimple(receiver, market, SY, YT, netSyInterm, minLpOut);

        emit AddLiquiditySingleToken(
            msg.sender,
            market,
            input.tokenIn,
            receiver,
            input.netTokenIn,
            netLpOut,
            netSyInterm
        );
    }

    function addLiquiditySingleSySimple(
        address receiver,
        address market,
        uint256 netSyIn,
        uint256 minLpOut
    ) external returns (uint256 netLpOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        _transferFrom(SY, msg.sender, address(this), netSyIn);

        (netLpOut, netSyFee) = _addLiquiditySingleSySimple(receiver, market, SY, YT, netSyIn, minLpOut);

        emit AddLiquiditySingleSy(msg.sender, market, receiver, netSyIn, netLpOut);
    }

    function _addLiquiditySingleSySimple(
        address receiver,
        address market,
        IStandardizedYield /*SY*/,
        IPYieldToken YT,
        uint256 netSyIn,
        uint256 minLpOut
    ) internal returns (uint256 netLpOut, uint256 netSyFee) {
        uint256 netSyLeft = netSyIn;
        uint256 netPtReceived;

        (uint256 netPtOutMarket, , , ) = _readMarket(market).approxSwapSyToAddLiquidity(
            YT.newIndex(),
            netSyLeft,
            netPtReceived,
            block.timestamp
        );

        (uint256 netSySwapMarket, uint256 netSyFeeMarket) = IPMarket(market).swapSyForExactPt(
            market,
            netPtOutMarket,
            EMPTY_BYTES
        );

        netSyLeft -= netSySwapMarket;
        netPtReceived += netPtOutMarket;
        netSyFee += netSyFeeMarket;

        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyLeft, netPtReceived);

        if (netLpOut < minLpOut) revert("Slippage: INSUFFICIENT_LP_OUT");
    }

    // ------------------ REMOVE LIQUIDITY SINGLE PT ------------------
    function removeLiquiditySinglePtSimple(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minPtOut
    ) external returns (uint256 netPtOut, uint256 netSyFee) {
        uint256 netSyLeft;

        // execute the burn
        _transferFrom(IERC20(market), msg.sender, market, netLpToRemove);
        (uint256 netSyOutBurn, uint256 netPtOutBurn) = IPMarket(market).burn(address(this), receiver, netLpToRemove);
        netSyLeft += netSyOutBurn;
        netPtOut += netPtOutBurn;

        (uint256 netPtOutSwap, uint256 netSyFeeSwap) = _swapExactSyForPtSimple(receiver, market, netSyLeft, 0);
        netPtOut += netPtOutSwap;
        netSyFee += netSyFeeSwap;

        if (netPtOut < minPtOut) revert("Slippage: INSUFFICIENT_PT_OUT");

        emit RemoveLiquiditySinglePt(msg.sender, market, receiver, netLpToRemove, netPtOut);
    }

    // ------------------ REMOVE LIQUIDITY SINGLE TOKEN ------------------

    function removeLiquiditySingleTokenSimple(
        address receiver,
        address market,
        uint256 netLpToRemove,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();

        _transferFrom(IERC20(market), msg.sender, market, netLpToRemove);

        (netSyInterm, netSyFee) = _removeLiquiditySingleSySimple(address(SY), market, netLpToRemove, 1);

        netTokenOut = _redeemSyToToken(receiver, address(SY), netSyInterm, output, false);

        emit RemoveLiquiditySingleToken(
            msg.sender,
            market,
            output.tokenOut,
            receiver,
            netLpToRemove,
            netTokenOut,
            netSyInterm
        );
    }

    function removeLiquiditySingleSySimple(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minSyOut
    ) external returns (uint256 netSyOut, uint256 netSyFee) {
        _transferFrom(IERC20(market), msg.sender, market, netLpToRemove);

        (netSyOut, netSyFee) = _removeLiquiditySingleSySimple(receiver, market, netLpToRemove, minSyOut);

        emit RemoveLiquiditySingleSy(msg.sender, market, receiver, netLpToRemove, netSyOut);
    }

    // the entry of this will always be market
    function _removeLiquiditySingleSySimple(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minSyOut
    ) internal returns (uint256 netSyOut, uint256 netSyFee) {
        if (IPMarket(market).isExpired()) {
            netSyOut = __removeLpToSyAfterExpirySimple(receiver, market, netLpToRemove);
        } else {
            (netSyOut, netSyFee) = __removeLpToSyBeforeExpirySimple(receiver, market, netLpToRemove);
        }
        if (netSyOut < minSyOut) revert("Slippage: INSUFFICIENT_SY_OUT");
    }

    function __removeLpToSyAfterExpirySimple(
        address receiver,
        address market,
        uint256 netLpToRemove
    ) internal returns (uint256 netSyOut) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        (uint256 syFromBurn, ) = IPMarket(market).burn(receiver, address(YT), netLpToRemove);
        netSyOut = syFromBurn + YT.redeemPY(receiver);
    }

    function __removeLpToSyBeforeExpirySimple(
        address receiver,
        address market,
        uint256 netLpToRemove
    ) internal returns (uint256 netSyOut, uint256 netSyFee) {
        uint256 netPtLeft;

        (uint256 netSyOutBurn, uint256 netPtOutBurn) = IPMarket(market).burn(receiver, address(this), netLpToRemove);
        netSyOut += netSyOutBurn;
        netPtLeft += netPtOutBurn;

        (uint256 netSyOutSwap, uint256 netSyFeeSwap) = _swapExactPtForSySimple(receiver, market, netPtLeft, 0);
        netSyOut += netSyOutSwap;
        netSyFee += netSyFeeSwap;
    }

    function _swapExactSyForPtSimple(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minPtOut
    ) internal returns (uint256 netPtOut, uint256 netSyFee) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        uint256 netSyLeft = exactSyIn;

        (uint256 netPtOutMarket, , ) = _readMarket(market).approxSwapExactSyForPt(
            YT.newIndex(),
            netSyLeft,
            block.timestamp
        );

        (, uint256 netSyFeeMarket) = IPMarket(market).swapSyForExactPt(receiver, netPtOutMarket, "");

        netPtOut += netPtOutMarket;
        netSyFee += netSyFeeMarket;

        if (netPtOut < minPtOut) revert("Slippage: INSUFFICIENT_PT_OUT");
    }

    function _swapExactSyForYtSimple(
        address receiver,
        address market,
        IStandardizedYield /* SY */,
        IPYieldToken YT,
        uint256 exactSyIn,
        uint256 minYtOut
    ) internal returns (uint256 netYtOut, uint256 netSyFee) {
        uint256 netSyLeft = exactSyIn;

        (uint256 netYtOutMarket, , ) = _readMarket(market).approxSwapExactSyForYt(
            YT.newIndex(),
            netSyLeft,
            block.timestamp
        );

        (, uint256 netSyFeeMarket) = IPMarket(market).swapExactPtForSy(
            address(YT),
            netYtOutMarket, // exactPtIn = netYtOut
            _encodeSwapExactSyForYt(receiver, YT)
        );

        netYtOut += netYtOutMarket;
        netSyFee += netSyFeeMarket;

        if (netYtOut < minYtOut) revert("Slippage: INSUFFICIENT_YT_OUT");
    }

    function _swapExactPtForSySimple(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minSyOut
    ) internal returns (uint256 netSyOut, uint256 netSyFee) {
        uint256 netPtLeft = exactPtIn;

        (uint256 netSyOutMarket, uint256 netSyFeeMarket) = IPMarket(market).swapExactPtForSy(receiver, netPtLeft, "");

        netSyOut += netSyOutMarket;
        netSyFee += netSyFeeMarket;

        if (netSyOut < minSyOut) revert("Slippage: INSUFFICIENT_SY_OUT");
    }
}
