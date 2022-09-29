// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../libraries/math/MarketApproxLib.sol";
import "../libraries/kyberswap/KyberSwapHelper.sol";

interface IPActionMintRedeem {
    event MintScyFromToken(
        address indexed caller,
        address indexed receiver,
        address indexed SCY,
        address tokenIn,
        uint256 netTokenIn,
        uint256 netScyOut
    );

    event RedeemScyToToken(
        address indexed caller,
        address indexed receiver,
        address indexed SCY,
        uint256 netScyIn,
        address tokenOut,
        uint256 netTokenOut
    );

    event MintPyFromScy(
        address indexed caller,
        address indexed receiver,
        address indexed YT,
        uint256 netScyIn,
        uint256 netPyOut
    );

    event RedeemPyToScy(
        address indexed caller,
        address indexed receiver,
        address indexed YT,
        uint256 netPyIn,
        uint256 netScyOut
    );

    event MintPyFromToken(
        address indexed caller,
        address indexed receiver,
        address indexed YT,
        address tokenIn,
        uint256 netTokenIn,
        uint256 netPyOut
    );

    event RedeemPyToToken(
        address indexed caller,
        address indexed receiver,
        address indexed YT,
        uint256 netPyIn,
        address tokenOut,
        uint256 netTokenOut
    );

    event RedeemDueInterestAndRewards(
        address indexed user,
        address[] scys,
        address[] yts,
        address[] markets,
        uint256[][] scyRewards,
        uint256[] ytInterests,
        uint256[][] ytRewards,
        uint256[][] marketRewards
    );

    event RedeemDueInterestAndRewardsThenSwapAll(
        address indexed user,
        address[] scys,
        address[] yts,
        address[] markets,
        address indexed tokenOut,
        uint256 netTokenOut
    );

    function mintScyFromToken(
        address receiver,
        address SCY,
        uint256 minScyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netScyOut);

    function redeemScyToToken(
        address receiver,
        address SCY,
        uint256 netScyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut);

    function mintPyFromToken(
        address receiver,
        address YT,
        uint256 minPyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netPyOut);

    function redeemPyToToken(
        address receiver,
        address YT,
        uint256 netPyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut);

    function mintPyFromScy(
        address receiver,
        address YT,
        uint256 netScyIn,
        uint256 minPyOut
    ) external returns (uint256 netPyOut);

    function redeemPyToScy(
        address receiver,
        address YT,
        uint256 netPyIn,
        uint256 minScyOut
    ) external returns (uint256 netScyOut);

    function redeemDueInterestAndRewards(
        address user,
        address[] calldata scys,
        address[] calldata yts,
        address[] calldata markets
    )
        external
        returns (
            uint256[][] memory scyRewards,
            uint256[] memory ytInterests,
            uint256[][] memory ytRewards,
            uint256[][] memory marketRewards
        );

    struct RouterYtRedeemStruct {
        address[] yts;
        // key-value pair
        address[] scyAddrs;
        address[] tokenRedeemScys;
        //
    }

    struct RouterSwapAllStruct {
        // key-value pair
        address[] tokens;
        bytes[] kybercalls;
        //
        address outputToken;
        uint256 minTokenOut;
    }

    function redeemDueInterestAndRewardsThenSwapAll(
        address[] calldata scys,
        RouterYtRedeemStruct calldata dataYT,
        address[] calldata markets,
        RouterSwapAllStruct calldata dataSwap
    ) external returns (uint256 netTokenOut, uint256[] memory amountsSwapped);
}
