// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../router/math/MarketApproxLibV2.sol";
import "./IPAllActionTypeV3.sol";
import {IPAllEventsV3} from "./IPAllEventsV3.sol";
import "./IStandardizedYield.sol";
import "./IPMarket.sol";

/// Refer to IPAllActionTypeV3.sol for details on the parameters
interface IPActionMiscV3 is IPAllEventsV3 {
    struct Call3 {
        bool allowFailure;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    function mintSyFromToken(
        address receiver,
        address SY,
        uint256 minSyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netSyOut);

    function redeemSyToToken(
        address receiver,
        address SY,
        uint256 netSyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut);

    function mintPyFromToken(
        address receiver,
        address YT,
        uint256 minPyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netPyOut, uint256 netSyInterm);

    function redeemPyToToken(
        address receiver,
        address YT,
        uint256 netPyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netSyInterm);

    function mintPyFromSy(
        address receiver,
        address YT,
        uint256 netSyIn,
        uint256 minPyOut
    ) external returns (uint256 netPyOut);

    function redeemPyToSy(
        address receiver,
        address YT,
        uint256 netPyIn,
        uint256 minSyOut
    ) external returns (uint256 netSyOut);

    function redeemDueInterestAndRewards(
        address user,
        address[] calldata sys,
        address[] calldata yts,
        address[] calldata markets
    ) external;

    function redeemDueInterestAndRewardsV2(
        IStandardizedYield[] calldata SYs,
        RedeemYtIncomeToTokenStruct[] calldata YTs,
        IPMarket[] calldata markets,
        IPSwapAggregator pendleSwap,
        SwapDataExtra[] calldata swaps
    ) external returns (uint256[] memory netOutFromSwaps, uint256[] memory netInterests);

    function swapTokensToTokens(
        IPSwapAggregator pendleSwap,
        SwapDataExtra[] calldata swaps,
        uint256[] calldata netSwaps
    ) external payable returns (uint256[] memory netOutFromSwaps);

    function swapTokenToTokenViaSy(
        address receiver,
        address SY,
        TokenInput calldata input,
        address tokenRedeemSy,
        uint256 minTokenOut
    ) external payable returns (uint256 netTokenOut, uint256 netSyInterm);

    function exitPreExpToToken(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 netYtIn,
        uint256 netLpIn,
        TokenOutput calldata output,
        LimitOrderData calldata limit
    ) external returns (uint256 netTokenOut, ExitPreExpReturnParams memory params);

    function exitPreExpToSy(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 netYtIn,
        uint256 netLpIn,
        uint256 minSyOut,
        LimitOrderData calldata limit
    ) external returns (ExitPreExpReturnParams memory params);

    function exitPostExpToToken(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 netLpIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, ExitPostExpReturnParams memory params);

    function exitPostExpToSy(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 netLpIn,
        uint256 minSyOut
    ) external returns (ExitPostExpReturnParams memory params);

    function callAndReflect(
        address payable reflector,
        bytes calldata selfCall1,
        bytes calldata selfCall2,
        bytes calldata reflectCall
    ) external payable returns (bytes memory selfRes1, bytes memory selfRes2, bytes memory reflectRes);

    function boostMarkets(address[] memory markets) external;

    function multicall(Call3[] calldata calls) external payable returns (Result[] memory res);

    function simulate(address target, bytes calldata data) external payable;
}
