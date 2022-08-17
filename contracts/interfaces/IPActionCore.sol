// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../libraries/math/MarketApproxLib.sol";
import "../libraries/kyberswap/KyberSwapHelper.sol";

interface IPActionCore {
    event AddLiquidityDualScyAndPt(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 scyUsed,
        uint256 ptUsed,
        uint256 lpOut
    );

    event AddLiquidityDualIbTokenAndPt(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 ibTokenUsed,
        uint256 ptUsed,
        uint256 lpOut
    );

    event RemoveLiquidityDualScyAndPt(
        address indexed caller,
        address indexed market,
        address receiver,
        uint256 lpIn,
        uint256 amountPTOut,
        uint256 amountSCYOut
    );

    event RemoveLiquidityDualIbTokenAndPt(
        address indexed caller,
        address indexed market,
        address receiver,
        uint256 lpIn,
        uint256 amountPTOut,
        uint256 amountIbTokenOut
    );

    event SwapPtAndScy(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        int256 amountPtToAccount,
        int256 amountScyToAccount
    );

    event SwapPtAndToken(
        address indexed caller,
        address indexed market,
        address indexed token,
        address receiver,
        int256 amountPtToAccount,
        int256 amountTokenToAccount
    );

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

    function addLiquidityDualScyAndPt(
        address receiver,
        address market,
        uint256 scyDesired,
        uint256 ptDesired,
        uint256 minLpOut
    )
        external
        returns (
            uint256 netLpOut,
            uint256 scyUsed,
            uint256 ptUsed
        );

    /// @dev refer to the internal function
    function addLiquidityDualIbTokenAndPt(
        address receiver,
        address market,
        uint256 ibTokenDesired,
        uint256 ptDesired,
        uint256 minLpOut
    )
        external
        returns (
            uint256 netLpOut,
            uint256 ibTokenUsed,
            uint256 ptUsed
        );

    function addLiquiditySinglePt(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtSwapToScy
    ) external returns (uint256 netLpOut);

    function addLiquiditySingleScy(
        address receiver,
        address market,
        uint256 netScyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromScy
    ) external returns (uint256 netLpOut);

    function addLiquiditySingleToken(
        address receiver,
        address market,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromScy,
        TokenInput calldata input
    ) external returns (uint256 netLpOut);

    function removeLiquidityDualScyAndPt(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 ptOutMin
    ) external returns (uint256 netScyOut, uint256 netPtOut);

    /// @dev refer to the internal function
    function removeLiquidityDualIbTokenAndPt(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 ibTokenMin,
        uint256 ptOutMin
    ) external returns (uint256 netIbTokenOut, uint256 netPtOut);

    function removeLiquiditySinglePt(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut
    ) external returns (uint256 netPtOut);

    function removeLiquiditySingleScy(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 minScyOut
    ) external returns (uint256 netScyOut);

    function removeLiquiditySingleToken(
        address receiver,
        address market,
        uint256 lpToRemove,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut);

    function swapExactPtForScy(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minScyOut
    ) external returns (uint256 netScyOut);

    function swapPtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        uint256 maxPtIn,
        ApproxParams calldata guessPtIn
    ) external returns (uint256 netPtIn);

    function swapScyForExactPt(
        address receiver,
        address market,
        uint256 exactPtOut,
        uint256 maxScyIn
    ) external returns (uint256 netScyIn);

    function swapExactScyForPt(
        address receiver,
        address market,
        uint256 exactScyIn,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut
    ) external returns (uint256 netPtOut);

    function mintScyFromToken(
        address receiver,
        address SCY,
        uint256 minScyOut,
        TokenInput calldata input
    ) external returns (uint256 netScyOut);

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
    ) external returns (uint256 netPyOut);

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

    function swapExactTokenForPt(
        address receiver,
        address market,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        TokenInput calldata input
    ) external returns (uint256 netPtOut);

    function swapExactPtForToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut);

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
}
