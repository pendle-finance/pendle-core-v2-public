// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./base/ActionBase.sol";
import "../interfaces/IPActionMiscV3.sol";
import "../interfaces/IPReflector.sol";

contract ActionMiscV3 is IPActionMiscV3, ActionBase {
    uint256 private constant NOT_FOUND = type(uint256).max;

    function mintSyFromToken(
        address receiver,
        address SY,
        uint256 minSyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netSyOut) {
        netSyOut = _mintSyFromToken(receiver, SY, minSyOut, input);
        emit MintSyFromToken(msg.sender, input.tokenIn, SY, receiver, input.netTokenIn, netSyOut);
    }

    /// @notice For details on the parameters (input, guessPtSwapToSy, limit, etc.), please refer to IPAllActionTypeV3.
    function redeemSyToToken(
        address receiver,
        address SY,
        uint256 netSyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut) {
        netTokenOut = _redeemSyToToken(receiver, SY, netSyIn, output, true);
        emit RedeemSyToToken(msg.sender, output.tokenOut, SY, receiver, netSyIn, netTokenOut);
    }

    /// @notice For details on the parameters (input, guessPtSwapToSy, limit, etc.), please refer to IPAllActionTypeV3.
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

    /// @notice For details on the parameters (input, guessPtSwapToSy, limit, etc.), please refer to IPAllActionTypeV3.
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

    /// @dev The interface might change in the future, check with Pendle team before use
    function redeemDueInterestAndRewardsV2(
        IStandardizedYield[] calldata SYs,
        RedeemYtIncomeToTokenStruct[] calldata YTs,
        IPMarket[] calldata markets,
        IPSwapAggregator pendleSwap,
        SwapDataExtra[] calldata swaps
    ) external returns (uint256[] memory netOutFromSwaps, uint256[] memory netInterests) {
        if (swaps.length == 0) {
            return (netOutFromSwaps, __redeemDueInterestAndRewardsV2NoSwap(SYs, YTs, markets));
        } else {
            return __redeemDueInterestAndRewardsV2AndSwap(SYs, YTs, markets, pendleSwap, swaps);
        }
    }

    function __redeemDueInterestAndRewardsV2NoSwap(
        IStandardizedYield[] calldata SYs,
        RedeemYtIncomeToTokenStruct[] calldata YTs,
        IPMarket[] calldata markets
    ) private returns (uint256[] memory netInterests) {
        netInterests = new uint256[](YTs.length);
        for (uint256 i = 0; i < SYs.length; ++i) SYs[i].claimRewards(msg.sender);

        for (uint256 i = 0; i < YTs.length; ++i) {
            (uint256 netSyInt, ) = YTs[i].yt.redeemDueInterestAndRewards(
                msg.sender,
                YTs[i].doRedeemInterest,
                YTs[i].doRedeemRewards
            );

            if (netSyInt == 0) continue;

            IStandardizedYield SY = IStandardizedYield(YTs[i].yt.SY());
            _transferFrom(SY, msg.sender, address(SY), netSyInt);
            netInterests[i] = SY.redeem(msg.sender, netSyInt, YTs[i].tokenRedeemSy, YTs[i].minTokenRedeemOut, true);
        }

        for (uint256 i = 0; i < markets.length; ++i) markets[i].redeemRewards(msg.sender);
    }

    function __redeemDueInterestAndRewardsV2AndSwap(
        IStandardizedYield[] calldata SYs,
        RedeemYtIncomeToTokenStruct[] calldata YTs,
        IPMarket[] calldata markets,
        IPSwapAggregator pendleSwap,
        SwapDataExtra[] calldata swaps
    ) private returns (uint256[] memory netOutFromSwaps, uint256[] memory netInterests) {
        netOutFromSwaps = new uint256[](swaps.length);
        uint256[] memory netSwaps = new uint256[](swaps.length);

        for (uint256 i = 0; i < SYs.length; ++i) {
            _add(swaps, netSwaps, SYs[i].getRewardTokens(), SYs[i].claimRewards(msg.sender));
        }

        netInterests = new uint256[](YTs.length);
        for (uint256 i = 0; i < YTs.length; ++i) {
            uint256[] memory netRewards;
            (netInterests[i], netRewards) = YTs[i].yt.redeemDueInterestAndRewards(
                msg.sender,
                YTs[i].doRedeemInterest,
                YTs[i].doRedeemRewards
            );

            if (YTs[i].doRedeemRewards) _add(swaps, netSwaps, YTs[i].yt.getRewardTokens(), netRewards);
        }

        for (uint256 i = 0; i < markets.length; ++i) {
            _add(swaps, netSwaps, markets[i].getRewardTokens(), markets[i].redeemRewards(msg.sender));
        }

        for (uint256 i = 0; i < swaps.length; ++i) {
            _transferIn(swaps[i].tokenIn, msg.sender, netSwaps[i]);
        }

        for (uint256 i = 0; i < YTs.length; ++i) {
            if (netInterests[i] == 0) continue;
            IStandardizedYield SY = IStandardizedYield(YTs[i].yt.SY());
            netInterests[i] = _redeemSyAndAdd(
                swaps,
                netSwaps,
                SY,
                netInterests[i],
                YTs[i].tokenRedeemSy,
                YTs[i].minTokenRedeemOut
            );
        }

        for (uint256 i = 0; i < swaps.length; ++i) netOutFromSwaps[i] = _swap(swaps[i], netSwaps[i], pendleSwap, true);
    }

    /// @dev The interface might change in the future, check with Pendle team before use
    function swapTokensToTokens(
        IPSwapAggregator pendleSwap,
        SwapDataExtra[] calldata swaps,
        uint256[] calldata netSwaps
    ) external payable returns (uint256[] memory netOutFromSwaps) {
        netOutFromSwaps = new uint256[](swaps.length);

        for (uint256 i = 0; i < swaps.length; ++i) {
            _transferIn(swaps[i].tokenIn, msg.sender, netSwaps[i]);
        }

        for (uint256 i = 0; i < swaps.length; ++i) {
            netOutFromSwaps[i] = _swap(swaps[i], netSwaps[i], pendleSwap, false);
        }
    }

    /// @dev The interface might change in the future, check with Pendle team before use
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

    /// @notice For details on the parameters (input, guessPtSwapToSy, limit, etc.), please refer to IPAllActionTypeV3.
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

    /// @notice For details on the parameters (input, guessPtSwapToSy, limit, etc.), please refer to IPAllActionTypeV3.
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

    /// @notice For details on the parameters (input, guessPtSwapToSy, limit, etc.), please refer to IPAllActionTypeV3.
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

    function _redeemSyAndAdd(
        SwapDataExtra[] calldata swaps,
        uint256[] memory netSwaps,
        IStandardizedYield SY,
        uint256 netSyToRedeem,
        address tokenRedeemSy,
        uint256 minTokenRedeemSy
    ) internal returns (uint256 netTokenOut) {
        _transferFrom(SY, msg.sender, address(SY), netSyToRedeem);

        uint256 index = _find(swaps, tokenRedeemSy);
        if (index == NOT_FOUND) {
            return SY.redeem(msg.sender, netSyToRedeem, tokenRedeemSy, minTokenRedeemSy, true);
        }

        netTokenOut = SY.redeem(address(this), netSyToRedeem, tokenRedeemSy, minTokenRedeemSy, true);
        netSwaps[index] += netTokenOut;
    }

    function _add(
        SwapDataExtra[] calldata swaps,
        uint256[] memory netSwaps,
        address[] memory tokens,
        uint256[] memory amounts
    ) internal pure {
        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 index = _find(swaps, tokens[i]);
            if (index == NOT_FOUND) continue;

            netSwaps[index] += amounts[i];
        }
    }

    function _swap(
        SwapDataExtra calldata $,
        uint256 netSwap,
        IPSwapAggregator pendleSwap,
        bool needScale
    ) internal returns (uint256 netTokenOut) {
        SwapType swapType = $.swapData.swapType;
        assert(swapType != SwapType.NONE);

        if (swapType == SwapType.ETH_WETH) {
            _wrap_unwrap_ETH($.tokenIn, $.tokenOut, netSwap);

            netTokenOut = netSwap;
        } else {
            assert($.swapData.needScale == needScale);

            _transferOut($.tokenIn, address(pendleSwap), netSwap);

            uint256 preBalance = _selfBalance($.tokenOut);
            IPSwapAggregator(pendleSwap).swap($.tokenIn, netSwap, $.swapData);
            netTokenOut = _selfBalance($.tokenOut) - preBalance;
        }

        require(netTokenOut >= $.minOut, "Slippage: INSUFFICIENT_TOKEN_OUT");
        _transferOut($.tokenOut, msg.sender, netTokenOut);
    }

    function _find(SwapDataExtra[] calldata swaps, address token) internal pure returns (uint256 index) {
        for (uint256 i = 0; i < swaps.length; ++i) {
            if (swaps[i].tokenIn == token) return i;
        }
        return NOT_FOUND;
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

    function _callToReflector(address payable reflector, bytes memory data) internal returns (bytes memory) {
        return IPReflector(reflector).reflect(data);
    }
}
