// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./base/ActionBase.sol";
import "../interfaces/IPActionMiscV3.sol";
import "../interfaces/IPReflector.sol";

contract ActionMiscV3 is IPActionMiscV3, ActionBase {
    function mintSyFromToken(
        address receiver,
        address SY,
        uint256 minSyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netSyOut) {
        netSyOut = _mintSyFromToken(receiver, SY, minSyOut, input);
        emit MintSyFromToken(msg.sender, input.tokenIn, SY, receiver, input.netTokenIn, netSyOut);
    }

    function redeemSyToToken(
        address receiver,
        address SY,
        uint256 netSyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut) {
        netTokenOut = _redeemSyToToken(receiver, SY, netSyIn, output, true);
        emit RedeemSyToToken(msg.sender, output.tokenOut, SY, receiver, netSyIn, netTokenOut);
    }

    function mintPyFromToken(
        address receiver,
        address YT,
        uint256 minPyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netPyOut, uint256 netSyInterm) {
        address SY = IPYieldToken(YT).SY();

        netSyInterm = _mintSyFromToken(YT, SY, 0, input);
        netPyOut = _mintPyFromSy(receiver, SY, YT, netSyInterm, minPyOut, false);

        emit MintPyFromToken(msg.sender, input.tokenIn, YT, receiver, input.netTokenIn, netPyOut, netSyInterm);
    }

    function redeemPyToToken(
        address receiver,
        address YT,
        uint256 netPyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netSyInterm) {
        address SY = IPYieldToken(YT).SY();

        netSyInterm = _redeemPyToSy(SY, YT, netPyIn, 1);
        netTokenOut = _redeemSyToToken(receiver, SY, netSyInterm, output, false);

        emit RedeemPyToToken(msg.sender, output.tokenOut, YT, receiver, netPyIn, netTokenOut, netSyInterm);
    }

    function mintPyFromSy(
        address receiver,
        address YT,
        uint256 netSyIn,
        uint256 minPyOut
    ) external returns (uint256 netPyOut) {
        netPyOut = _mintPyFromSy(receiver, IPYieldToken(YT).SY(), YT, netSyIn, minPyOut, true);
        emit MintPyFromSy(msg.sender, receiver, YT, netSyIn, netPyOut);
    }

    function redeemPyToSy(
        address receiver,
        address YT,
        uint256 netPyIn,
        uint256 minSyOut
    ) external returns (uint256 netSyOut) {
        netSyOut = _redeemPyToSy(receiver, YT, netPyIn, minSyOut);
        emit RedeemPyToSy(msg.sender, receiver, YT, netPyIn, netSyOut);
    }

    function redeemDueInterestAndRewards(
        address user,
        address[] calldata sys,
        address[] calldata yts,
        address[] calldata markets
    ) external {
        for (uint256 i = 0; i < sys.length; ++i) {
            IStandardizedYield(sys[i]).claimRewards(user);
        }

        for (uint256 i = 0; i < yts.length; ++i) {
            IPYieldToken(yts[i]).redeemDueInterestAndRewards(user, true, true);
        }

        for (uint256 i = 0; i < markets.length; ++i) {
            IPMarket(markets[i]).redeemRewards(user);
        }
    }

    function swapTokenToToken(
        address receiver,
        uint256 minTokenOut,
        TokenInput calldata inp
    ) external payable returns (uint256 netTokenOut) {
        _swapTokenInput(inp);

        netTokenOut = _selfBalance(inp.tokenMintSy);
        if (netTokenOut < minTokenOut) revert("Slippage: INSUFFICIENT_TOKEN_OUT");

        _transferOut(inp.tokenMintSy, receiver, netTokenOut);
    }

    function swapTokenToTokenViaSy(
        address receiver,
        address SY,
        TokenInput calldata input,
        address tokenRedeemSy,
        uint256 minTokenOut
    ) external payable returns (uint256 netTokenOut, uint256 netSyInterm) {
        netSyInterm = _mintSyFromToken(SY, SY, 0, input);
        netTokenOut = IStandardizedYield(SY).redeem(receiver, netSyInterm, tokenRedeemSy, minTokenOut, true);
    }

    /// @dev The interface might change in the future, check with Pendle team before use
    function exitPreExpToToken(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 netYtIn,
        uint256 netLpIn,
        TokenOutput calldata output,
        LimitOrderData calldata limit
    ) external returns (uint256 totalTokenOut, ExitPreExpReturnParams memory params) {
        IStandardizedYield SY;

        (SY, params) = _exitPreExpToSy(true, address(0), market, netPtIn, netYtIn, netLpIn, limit);
        totalTokenOut = _redeemSyToToken(receiver, address(SY), params.totalSyOut, output, false);

        emit ExitPreExpToToken(msg.sender, market, output.tokenOut, receiver, netLpIn, totalTokenOut, params);
    }

    /// @dev The interface might change in the future, check with Pendle team before use
    function exitPreExpToSy(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 netYtIn,
        uint256 netLpIn,
        uint256 minSyOut,
        LimitOrderData calldata limit
    ) external returns (ExitPreExpReturnParams memory params) {
        (, params) = _exitPreExpToSy(false, receiver, market, netPtIn, netYtIn, netLpIn, limit);
        require(params.totalSyOut >= minSyOut, "Slippage: INSUFFICIENT_SY_OUT");

        emit ExitPreExpToSy(msg.sender, market, receiver, netLpIn, params);
    }

    function _exitPreExpToSy(
        bool setReceiverToSy,
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 netYtIn,
        uint256 netLpIn,
        LimitOrderData calldata limit
    ) internal returns (IStandardizedYield SY, ExitPreExpReturnParams memory p) {
        IPPrincipalToken PT;
        IPYieldToken YT;
        (SY, PT, YT) = IPMarket(market).readTokens();

        if (setReceiverToSy) receiver = address(SY);

        if (netLpIn > 0) {
            _transferFrom(IERC20(market), msg.sender, market, netLpIn);
            (p.netSyFromRemove, p.netPtFromRemove) = IPMarket(market).burn(receiver, address(this), netLpIn);
        }

        if (netPtIn > 0) {
            _transferIn(address(PT), msg.sender, netPtIn);
        }

        p.netPyRedeem = PMath.min(p.netPtFromRemove + netPtIn, netYtIn);

        if (p.netPyRedeem > 0) {
            _transferOut(address(PT), address(YT), p.netPyRedeem);
            _transferFrom(YT, msg.sender, address(YT), p.netPyRedeem);
            p.netSyFromRedeem = IPYieldToken(YT).redeemPY(receiver);
        }

        p.netPtSwap = p.netPtFromRemove + netPtIn - p.netPyRedeem;
        p.netYtSwap = netYtIn - p.netPyRedeem;

        if (p.netPtSwap > 0) {
            address ptEntry = _entry_swapExactPtForSy(market, limit);
            if (ptEntry != address(this)) _transferOut(address(PT), ptEntry, p.netPtSwap);
            (p.netSyFromSwap, p.netSyFee) = _swapExactPtForSy(receiver, market, p.netPtSwap, 0, limit);
        } else if (p.netYtSwap > 0) {
            _transferFrom(YT, msg.sender, _entry_swapExactYtForSy(YT, limit), p.netYtSwap);
            (p.netSyFromSwap, p.netSyFee) = _swapExactYtForSy(receiver, market, SY, YT, p.netYtSwap, 0, limit);
        }

        p.totalSyOut = p.netSyFromRemove + p.netSyFromRedeem + p.netSyFromSwap;
    }

    /// @dev The interface might change in the future, check with Pendle team before use
    function exitPostExpToToken(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 netLpIn,
        TokenOutput calldata output
    ) external returns (uint256 totalTokenOut, ExitPostExpReturnParams memory params) {
        IStandardizedYield SY;

        (SY, params) = _exitPostExpToSy(true, address(0), market, netPtIn, netLpIn);
        totalTokenOut = _redeemSyToToken(receiver, address(SY), params.totalSyOut, output, false);

        emit ExitPostExpToToken(msg.sender, market, output.tokenOut, receiver, netLpIn, totalTokenOut, params);
    }

    /// @dev The interface might change in the future, check with Pendle team before use
    function exitPostExpToSy(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 netLpIn,
        uint256 minSyOut
    ) external returns (ExitPostExpReturnParams memory params) {
        (, params) = _exitPostExpToSy(false, receiver, market, netPtIn, netLpIn);
        require(params.totalSyOut >= minSyOut, "Slippage: INSUFFICIENT_SY_OUT");

        emit ExitPostExpToSy(msg.sender, market, receiver, netLpIn, params);
    }

    function _exitPostExpToSy(
        bool setReceiverToSy,
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 netLpIn
    ) internal returns (IStandardizedYield SY, ExitPostExpReturnParams memory p) {
        IPPrincipalToken PT;
        IPYieldToken YT;
        (SY, PT, YT) = IPMarket(market).readTokens();

        if (setReceiverToSy) receiver = address(SY);

        if (netLpIn > 0) {
            _transferFrom(IERC20(market), msg.sender, market, netLpIn);
            (p.netSyFromRemove, p.netPtFromRemove) = IPMarket(market).burn(receiver, address(YT), netLpIn);
        }

        if (netPtIn > 0) {
            _transferFrom(PT, msg.sender, address(YT), netPtIn);
        }

        p.netPtRedeem = p.netPtFromRemove + netPtIn;
        p.netSyFromRedeem = IPYieldToken(YT).redeemPY(receiver);

        p.totalSyOut = p.netSyFromRemove + p.netSyFromRedeem;
    }

    // ----------------- MISC FUNCTIONS -----------------

    function boostMarkets(address[] memory markets) external {
        for (uint256 i = 0; i < markets.length; i++) {
            IPMarket(markets[i]).transferFrom(msg.sender, markets[i], 0);
        }
    }

    function multicall(Call3[] calldata calls) external payable returns (Result[] memory res) {
        uint256 length = calls.length;
        res = new Result[](length);
        for (uint256 i = 0; i < length; i++) {
            (bool success, bytes memory result) = _delegateToSelf(calls[i].callData, calls[i].allowFailure);
            res[i] = Result(success, result);
        }
    }

    /// @dev The interface might change in the future, check with Pendle team before use
    function callAndReflect(
        address payable reflector,
        bytes calldata selfCall1,
        bytes calldata selfCall2,
        bytes calldata reflectCall
    ) external payable returns (bytes memory selfRes1, bytes memory selfRes2, bytes memory reflectRes) {
        (, selfRes1) = _delegateToSelf(selfCall1, false);
        if (selfCall2.length > 0) (, selfRes2) = _delegateToSelf(selfCall2, false);
        reflectRes = _callToReflector(reflector, reflectCall);
    }

    function simulate(address target, bytes calldata data) external payable {
        (bool success, bytes memory result) = target.delegatecall(data);
        revert Errors.SimulationResults(success, result);
    }

    function _delegateToSelf(
        bytes memory data,
        bool allowFailure
    ) internal returns (bool success, bytes memory result) {
        (success, result) = address(this).delegatecall(data);

        if (!success && !allowFailure) {
            assembly {
                // We use Yul's revert() to bubble up errors from the target contract.
                revert(add(32, result), mload(result))
            }
        }
    }

    function _callToReflector(address payable reflector, bytes memory data) internal returns (bytes memory) {
        return IPReflector(reflector).reflect(data);
    }
}
