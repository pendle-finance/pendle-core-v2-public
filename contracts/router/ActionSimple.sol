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
    /// @notice This function is for internal router use only and should not be called directly.
    /// @dev Use swapExactTokenForPt from the main router instead.
    /// @dev The interface of this simple function is subject to change without notice.
    function swapExactTokenForPtSimple(
        address receiver,
        address market,
        uint256 minPtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
        netSyInterm = _mintSyFromToken(_entry_swapExactSyForPt(market, false), address(SY), 1, input);

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

    /// @notice This function is for internal router use only and should not be called directly.
    /// @dev Use swapExactSyForPt from the main router instead.
    /// @dev The interface of this simple function is subject to change without notice.
    function swapExactSyForPtSimple(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minPtOut
    ) external returns (uint256 netPtOut, uint256 netSyFee) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
        _transferFrom(SY, msg.sender, _entry_swapExactSyForPt(market, false), exactSyIn);

        (netPtOut, netSyFee) = _swapExactSyForPtSimple(receiver, market, exactSyIn, minPtOut);
        emit SwapPtAndSy(msg.sender, market, receiver, netPtOut.Int(), exactSyIn.neg());
    }

    /// @notice This function is for internal router use only and should not be called directly.
    /// @dev Use swapExactTokenForYt from the main router instead.
    /// @dev The interface of this simple function is subject to change without notice.
    function swapExactTokenForYtSimple(
        address receiver,
        address market,
        uint256 minYtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netYtOut, uint256 netSyFee, uint256 netSyInterm) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        netSyInterm = _mintSyFromToken(_entry_swapExactSyForYt(YT, false), address(SY), 1, input);
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

    /// @notice This function is for internal router use only and should not be called directly.
    /// @dev Use swapExactSyForYt from the main router instead.
    /// @dev The interface of this simple function is subject to change without notice.
    function swapExactSyForYtSimple(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minYtOut
    ) external returns (uint256 netYtOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();
        _transferFrom(SY, msg.sender, _entry_swapExactSyForYt(YT, false), exactSyIn);

        (netYtOut, netSyFee) = _swapExactSyForYtSimple(receiver, market, SY, YT, exactSyIn, minYtOut);
        emit SwapYtAndSy(msg.sender, market, receiver, netYtOut.Int(), exactSyIn.neg());
    }

    /// @notice This function is for internal router use only and should not be called directly.
    /// @dev Use addLiquiditySinglePt from the main router instead.
    /// @dev The interface of this simple function is subject to change without notice.
    function addLiquiditySinglePtSimple(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 minLpOut
    ) external returns (uint256 netLpOut, uint256 netSyFee) {
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();
        _transferFrom(PT, msg.sender, _entry_addLiquiditySinglePt(market, false), netPtIn);

        uint256 netPtLeft = netPtIn;
        uint256 netSyReceived;

        (uint256 netPtSwapMarket, , , ) = _readMarket(market).approxSwapPtToAddLiquidityOnchain(
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

    /// @notice This function is for internal router use only and should not be called directly.
    /// @dev Use addLiquiditySingleToken from the main router instead.
    /// @dev The interface of this simple function is subject to change without notice.
    function addLiquiditySingleTokenSimple(
        address receiver,
        address market,
        uint256 minLpOut,
        TokenInput calldata input
    ) external payable returns (uint256 netLpOut, uint256 netSyFee, uint256 netSyInterm) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        netSyInterm = _mintSyFromToken(_entry_addLiquiditySingleSy(market, false), address(SY), 1, input);

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

    /// @notice This function is for internal router use only and should not be called directly.
    /// @dev Use addLiquiditySingleSy from the main router instead.
    /// @dev The interface of this simple function is subject to change without notice.
    function addLiquiditySingleSySimple(
        address receiver,
        address market,
        uint256 netSyIn,
        uint256 minLpOut
    ) external returns (uint256 netLpOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        _transferFrom(SY, msg.sender, _entry_addLiquiditySingleSy(market, false), netSyIn);

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

        (uint256 netPtOutMarket, , , ) = _readMarket(market).approxSwapSyToAddLiquidityOnchain(
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
    /// @notice This function is for internal router use only and should not be called directly.
    /// @dev Use removeLiquiditySinglePt from the main router instead.
    /// @dev The interface of this simple function is subject to change without notice.
    function removeLiquiditySinglePtSimple(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minPtOut
    ) external returns (uint256 netPtOut, uint256 netSyFee) {
        uint256 netSyLeft;

        // execute the burn
        _transferFrom(IERC20(market), msg.sender, market, netLpToRemove);
        (uint256 netSyOutBurn, uint256 netPtOutBurn) = IPMarket(market).burn(
            _entry_swapExactSyForPt(market, false),
            receiver,
            netLpToRemove
        );
        netSyLeft += netSyOutBurn;
        netPtOut += netPtOutBurn;

        (uint256 netPtOutSwap, uint256 netSyFeeSwap) = _swapExactSyForPtSimple(receiver, market, netSyLeft, 0);
        netPtOut += netPtOutSwap;
        netSyFee += netSyFeeSwap;

        if (netPtOut < minPtOut) revert("Slippage: INSUFFICIENT_PT_OUT");

        emit RemoveLiquiditySinglePt(msg.sender, market, receiver, netLpToRemove, netPtOut);
    }

    function _swapExactSyForPtSimple(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minPtOut
    ) internal returns (uint256 netPtOut, uint256 netSyFee) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        uint256 netSyLeft = exactSyIn;

        (uint256 netPtOutMarket, , ) = _readMarket(market).approxSwapExactSyForPtOnchain(
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

        (uint256 netYtOutMarket, , ) = _readMarket(market).approxSwapExactSyForYtOnchain(
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
}
