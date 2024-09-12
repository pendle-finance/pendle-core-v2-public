// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./base/ActionBase.sol";
import "../interfaces/IPActionSwapPTV3.sol";
import {ActionDelegateBase} from "./base/ActionDelegateBase.sol";

contract ActionSwapPTV3 is IPActionSwapPTV3, ActionBase, ActionDelegateBase {
    using PMath for uint256;

    // ------------------ SWAP TOKEN FOR PT ------------------
    /// @param guessPtOut - Parameter for the approximation if an
    ///   off-chain result is available beforehand.
    ///
    ///   It is recommended to use Pendle's Hosted SDK to generate this parameter
    ///   for optimal gas usage.
    ///
    ///   To enable on-chain approximation, use the helper function in
    ///   `/contracts/interfaces/IPAllActionTypeV3.sol` to generate this parameter,
    ///   or the router's simple function in `/contracts/interfaces/IPActionSimple.sol`.
    ///
    /// @param input - Parameters containing the details needed to swap and wrap
    ///   tokens into the corresponding SY of the specified `market`, including
    ///   information for performing swaps via an external aggregator.
    ///
    ///   It is recommended to use Pendle's Hosted SDK to generate this parameter,
    ///   which will also handle swaps via the external aggregator.
    ///
    ///   If a swap via an external aggregator is not required, use the helper
    ///   function in `/contracts/interfaces/IPAllActionTypeV3.sol` to generate
    ///   this parameter.
    ///
    /// @param limit - Parmeter containing all limit order information that
    ///   can be used in Pendle limit order.
    ///
    ///   It is recommended to use Pendle's Hosted SDK to generate this parameter
    ///   to have liquidity from limit orders.
    ///
    ///   To not use Pendle limit order, use the helper function in
    ///   `/contracts/interfaces/IPAllActionTypeV3.sol` to generate this parameter,
    ///   or the router's simple function in `/contracts/interfaces/IPActionSimple.sol`.
    function swapExactTokenForPt(
        address receiver,
        address market,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        TokenInput calldata input,
        LimitOrderData calldata limit
    ) external payable returns (uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm) {
        bool delegatedToSimple;
        (delegatedToSimple, netPtOut, netSyFee, netSyInterm) = (
            tryDelegateToSwapExactTokenForPtSimple(receiver, market, minPtOut, guessPtOut, input, limit)
        );
        if (delegatedToSimple) return (netPtOut, netSyFee, netSyInterm);

        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
        netSyInterm = _mintSyFromToken(_entry_swapExactSyForPt(market, limit), address(SY), 1, input);

        (netPtOut, netSyFee) = _swapExactSyForPt(receiver, market, netSyInterm, minPtOut, guessPtOut, limit);
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

    /// @param guessPtOut - Parameter for the approximation if an
    ///   off-chain result is available beforehand.
    ///
    ///   It is recommended to use Pendle's Hosted SDK to generate this parameter
    ///   for optimal gas usage.
    ///
    ///   To enable on-chain approximation, use the helper function in
    ///   `/contracts/interfaces/IPAllActionTypeV3.sol` to generate this parameter,
    ///   or the router's simple function in `/contracts/interfaces/IPActionSimple.sol`.
    ///
    /// @param limit - Parmeter containing all limit order information that
    ///   can be used in Pendle limit order.
    ///
    ///   It is recommended to use Pendle's Hosted SDK to generate this parameter
    ///   to have liquidity from limit orders.
    ///
    ///   To not use Pendle limit order, use the helper function in
    ///   `/contracts/interfaces/IPAllActionTypeV3.sol` to generate this parameter,
    ///   or the router's simple function in `/contracts/interfaces/IPActionSimple.sol`.
    function swapExactSyForPt(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        LimitOrderData calldata limit
    ) external returns (uint256 netPtOut, uint256 netSyFee) {
        bool delegatedToSimple;
        (delegatedToSimple, netPtOut, netSyFee) = (
            tryDelegateToSwapExactSyForPtSimple(receiver, market, exactSyIn, minPtOut, guessPtOut, limit)
        );
        if (delegatedToSimple) return (netPtOut, netSyFee);

        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
        _transferFrom(SY, msg.sender, _entry_swapExactSyForPt(market, limit), exactSyIn);

        (netPtOut, netSyFee) = _swapExactSyForPt(receiver, market, exactSyIn, minPtOut, guessPtOut, limit);
        emit SwapPtAndSy(msg.sender, market, receiver, netPtOut.Int(), exactSyIn.neg());
    }

    /// @param output - Parameters containing the details needed to unwrap and
    ///   swap from the corresponding SY of the specified `market` into a token,
    ///   including information for performing swaps via an external aggregator.
    ///
    ///   It is recommended to use Pendle's Hosted SDK to generate this parameter,
    ///   as it will also handle swaps via the external aggregator.
    ///
    ///   If a swap via an external aggregator is not required, use the helper
    ///   function in `/contracts/interfaces/IPAllActionTypeV3.sol` to generate
    ///   this parameter.
    ///
    /// @param limit - Parmeter containing all limit order information that
    ///   can be used in Pendle limit order.
    ///
    ///   It is recommended to use Pendle's Hosted SDK to generate this parameter
    ///   to have liquidity from limit orders.
    ///
    ///   To not use Pendle limit order, use the helper function in
    ///   `/contracts/interfaces/IPAllActionTypeV3.sol` to generate this parameter,
    ///   or the router's simple function in `/contracts/interfaces/IPActionSimple.sol`.
    function swapExactPtForToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output,
        LimitOrderData calldata limit
    ) external returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm) {
        (IStandardizedYield SY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();
        _transferFrom(PT, msg.sender, _entry_swapExactPtForSy(market, limit), exactPtIn);

        (netSyInterm, netSyFee) = _swapExactPtForSy(address(SY), market, exactPtIn, 0, limit);

        netTokenOut = _redeemSyToToken(receiver, address(SY), netSyInterm, output, false);

        emit SwapPtAndToken(
            msg.sender,
            market,
            output.tokenOut,
            receiver,
            exactPtIn.neg(),
            netTokenOut.Int(),
            netSyInterm
        );
    }

    /// @param limit - Parmeter containing all limit order information that
    ///   can be used in Pendle limit order.
    ///
    ///   It is recommended to use Pendle's Hosted SDK to generate this parameter
    ///   to have liquidity from limit orders.
    ///
    ///   To not use Pendle limit order, use the helper function in
    ///   `/contracts/interfaces/IPAllActionTypeV3.sol` to generate this parameter,
    ///   or the router's simple function in `/contracts/interfaces/IPActionSimple.sol`.
    function swapExactPtForSy(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minSyOut,
        LimitOrderData calldata limit
    ) external returns (uint256 netSyOut, uint256 netSyFee) {
        (, IPPrincipalToken PT, ) = IPMarket(market).readTokens();
        _transferFrom(PT, msg.sender, _entry_swapExactPtForSy(market, limit), exactPtIn);

        (netSyOut, netSyFee) = _swapExactPtForSy(receiver, market, exactPtIn, minSyOut, limit);
        emit SwapPtAndSy(msg.sender, market, receiver, exactPtIn.neg(), netSyOut.Int());
    }
}
