// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../libraries/math/MarketApproxLib.sol";
import "../libraries/kyberswap/KyberSwapHelper.sol";

interface IPActionSwapYT {
    event SwapYtAndScy(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        int256 netYtToAccount,
        int256 netScyToAccount
    );

    event SwapYtAndToken(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        address token,
        int256 netYtToAccount,
        int256 netTokenToAccount
    );

    function swapExactYtForScy(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minScyOut
    ) external returns (uint256 netScyOut);

    function swapScyForExactYt(
        address receiver,
        address market,
        uint256 exactYtOut,
        uint256 maxScyIn
    ) external returns (uint256 netScyIn);

    function swapExactScyForYt(
        address receiver,
        address market,
        uint256 exactScyIn,
        uint256 minYtOut,
        ApproxParams memory guessYtOut
    ) external returns (uint256 netYtOut);

    function swapYtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        uint256 maxYtIn,
        ApproxParams memory guessYtIn
    ) external returns (uint256 netYtIn);

    function swapExactTokenForYt(
        address receiver,
        address market,
        uint256 minYtOut,
        ApproxParams memory guessYtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netYtOut);

    function swapExactYtForToken(
        address receiver,
        address market,
        uint256 netYtIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut);
}
