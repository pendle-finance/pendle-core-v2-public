// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../router/base/MarketApproxLib.sol";
import "./IPAllActionTypeV3.sol";

/*
 *******************************************************************************************************************
 *******************************************************************************************************************
 * NOTICE *
 * Refer to https://docs.pendle.finance/Developers/Contracts/PendleRouter for more information on
 * TokenInput, TokenOutput, ApproxParams, LimitOrderData
 * It's recommended to use Pendle's Hosted SDK to generate the params
 *******************************************************************************************************************
 *******************************************************************************************************************
 */

interface IPActionMiscV3 {
    struct Call3 {
        bool allowFailure;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    struct ExitPreExpReturnParams {
        uint256 netPtFromRemove;
        uint256 netSyFromRemove;
        uint256 netPyRedeem;
        uint256 netSyFromRedeem;
        uint256 netPtSwap;
        uint256 netYtSwap;
        uint256 netSyFromSwap;
        uint256 netSyFee;
        uint256 totalSyOut;
    }

    struct ExitPostExpReturnParams {
        uint256 netPtFromRemove;
        uint256 netSyFromRemove;
        uint256 netPtRedeem;
        uint256 netSyFromRedeem;
        uint256 totalSyOut;
    }

    event MintSyFromToken(
        address indexed caller,
        address indexed tokenIn,
        address indexed SY,
        address receiver,
        uint256 netTokenIn,
        uint256 netSyOut
    );

    event RedeemSyToToken(
        address indexed caller,
        address indexed tokenOut,
        address indexed SY,
        address receiver,
        uint256 netSyIn,
        uint256 netTokenOut
    );

    event MintPyFromSy(
        address indexed caller,
        address indexed receiver,
        address indexed YT,
        uint256 netSyIn,
        uint256 netPyOut
    );

    event RedeemPyToSy(
        address indexed caller,
        address indexed receiver,
        address indexed YT,
        uint256 netPyIn,
        uint256 netSyOut
    );

    event MintPyFromToken(
        address indexed caller,
        address indexed tokenIn,
        address indexed YT,
        address receiver,
        uint256 netTokenIn,
        uint256 netPyOut,
        uint256 netSyInterm
    );

    event RedeemPyToToken(
        address indexed caller,
        address indexed tokenOut,
        address indexed YT,
        address receiver,
        uint256 netPyIn,
        uint256 netTokenOut,
        uint256 netSyInterm
    );

    event ExitPreExpToToken(
        address indexed caller,
        address indexed market,
        address indexed token,
        address receiver,
        uint256 netLpIn,
        uint256 totalTokenOut,
        ExitPreExpReturnParams params
    );

    event ExitPreExpToSy(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 netLpIn,
        ExitPreExpReturnParams params
    );

    event ExitPostExpToToken(
        address indexed caller,
        address indexed market,
        address indexed token,
        address receiver,
        uint256 netLpIn,
        uint256 totalTokenOut,
        ExitPostExpReturnParams params
    );

    event ExitPostExpToSy(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 netLpIn,
        ExitPostExpReturnParams params
    );

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

    function swapTokenToToken(
        address receiver,
        uint256 minTokenOut,
        TokenInput calldata inp
    ) external payable returns (uint256 netTokenOut);

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
