// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPActionMintRedeemStatic {
    function getAmountTokenToMintSy(
        address SY,
        address tokenIn,
        uint256 netSyOut
    ) external view returns (uint256 netTokenIn);

    function mintPyFromSyStatic(address YT, uint256 netSyToMint) external view returns (uint256 netPYOut);

    function mintPyFromTokenStatic(
        address YT,
        address tokenIn,
        uint256 netTokenIn
    ) external view returns (uint256 netPyOut);

    function mintSyFromTokenStatic(
        address SY,
        address tokenIn,
        uint256 netTokenIn
    ) external view returns (uint256 netSyOut);

    function redeemPyToSyStatic(address YT, uint256 netPYToRedeem) external view returns (uint256 netSyOut);

    function redeemPyToTokenStatic(
        address YT,
        uint256 netPYToRedeem,
        address tokenOut
    ) external view returns (uint256 netTokenOut);

    function redeemSyToTokenStatic(
        address SY,
        address tokenOut,
        uint256 netSyIn
    ) external view returns (uint256 netTokenOut);

    function pyIndexCurrentViewMarket(address market) external view returns (uint256);

    function pyIndexCurrentViewYt(address yt) external view returns (uint256);
}
