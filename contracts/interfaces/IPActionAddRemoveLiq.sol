// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../libraries/math/MarketApproxLib.sol";
import "../libraries/kyberswap/KyberSwapHelper.sol";

interface IPActionAddRemoveLiq {
    event AddLiquidityDualScyAndPt(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 scyUsed,
        uint256 ptUsed,
        uint256 lpOut
    );

    event AddLiquidityDualTokenAndPt(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        address tokenIn,
        uint256 tokenUsed,
        uint256 ptUsed,
        uint256 lpOut
    );

    event AddLiquiditySinglePt(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 netPtIn,
        uint256 netLpOut
    );

    event AddLiquiditySingleScy(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 netScyIn,
        uint256 netLpOut
    );

    event AddLiquiditySingleToken(
        address indexed caller,
        address indexed market,
        address indexed token,
        address receiver,
        uint256 netTokenIn,
        uint256 netLpOut
    );

    event RemoveLiquidityDualScyAndPt(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 netLpIn,
        uint256 amountPTOut,
        uint256 amountSCYOut
    );

    event RemoveLiquidityDualTokenAndPt(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 lpIn,
        uint256 amountPTOut,
        address tokenOut,
        uint256 amountTokenOut
    );

    event RemoveLiquiditySinglePt(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 lpToRemove,
        uint256 netPtOut
    );

    event RemoveLiquiditySingleScy(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 lpToRemove,
        uint256 netScyOut
    );

    event RemoveLiquiditySingleToken(
        address indexed caller,
        address indexed market,
        address indexed token,
        address receiver,
        uint256 lpToRemove,
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

    function addLiquidityDualTokenAndPt(
        address receiver,
        address market,
        address tokenIn,
        uint256 tokenDesired,
        uint256 ptDesired,
        uint256 minLpOut
    )
        external
        payable
        returns (
            uint256 netLpOut,
            uint256 tokenUsed,
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
    ) external payable returns (uint256 netLpOut);

    function removeLiquidityDualScyAndPt(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 ptOutMin
    ) external returns (uint256 netScyOut, uint256 netPtOut);

    function removeLiquidityDualTokenAndPt(
        address receiver,
        address market,
        uint256 lpToRemove,
        address tokenOut,
        uint256 tokenOutMin,
        uint256 ptOutMin
    ) external returns (uint256 netTokenOut, uint256 netPtOut);

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
}
