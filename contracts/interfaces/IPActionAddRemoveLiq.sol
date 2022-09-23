// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../libraries/math/MarketApproxLib.sol";
import "../libraries/kyberswap/KyberSwapHelper.sol";

interface IPActionAddRemoveLiq {
    event AddLiquidityDualScyAndPt(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 netScyUsed,
        uint256 netPtUsed,
        uint256 netLpOut
    );

    event AddLiquidityDualTokenAndPt(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        address tokenIn,
        uint256 tokenUsed,
        uint256 netPtUsed,
        uint256 netLpOut
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
        uint256 netLpToRemove,
        uint256 netPtOut,
        uint256 netScyOut
    );

    event RemoveLiquidityDualTokenAndPt(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 netLpToRemove,
        uint256 netPtOut,
        address tokenOut,
        uint256 netTokenOut
    );

    event RemoveLiquiditySinglePt(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 netLpToRemove,
        uint256 netPtOut
    );

    event RemoveLiquiditySingleScy(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 netLpToRemove,
        uint256 netScyOut
    );

    event RemoveLiquiditySingleToken(
        address indexed caller,
        address indexed market,
        address indexed token,
        address receiver,
        uint256 netLpToRemove,
        uint256 netTokenOut
    );

    function addLiquidityDualScyAndPt(
        address receiver,
        address market,
        uint256 netScyDesired,
        uint256 netPtDesired,
        uint256 minLpOut
    )
        external
        returns (
            uint256 netLpOut,
            uint256 netScyUsed,
            uint256 netPtUsed
        );

    function addLiquidityDualTokenAndPt(
        address receiver,
        address market,
        address tokenIn,
        uint256 netTokenDesired,
        uint256 netPtDesired,
        uint256 minLpOut
    )
        external
        payable
        returns (
            uint256 netLpOut,
            uint256 netTokenUsed,
            uint256 netPtUsed
        );

    function addLiquiditySinglePt(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtSwapToScy
    ) external returns (uint256 netLpOut, uint256 netScyFee);

    function addLiquiditySingleScy(
        address receiver,
        address market,
        uint256 netScyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromScy
    ) external returns (uint256 netLpOut, uint256 netScyFee);

    function addLiquiditySingleToken(
        address receiver,
        address market,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromScy,
        TokenInput calldata input
    ) external payable returns (uint256 netLpOut, uint256 netScyFee);

    function removeLiquidityDualScyAndPt(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minScyOut,
        uint256 minPtOut
    ) external returns (uint256 netScyOut, uint256 netPtOut);

    function removeLiquidityDualTokenAndPt(
        address receiver,
        address market,
        uint256 netLpToRemove,
        address tokenOut,
        uint256 minTokenOut,
        uint256 minPtOut
    ) external returns (uint256 netTokenOut, uint256 netPtOut);

    function removeLiquiditySinglePt(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut
    ) external returns (uint256 netPtOut, uint256 netScyFee);

    function removeLiquiditySingleScy(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minScyOut
    ) external returns (uint256 netScyOut, uint256 netScyFee);

    function removeLiquiditySingleToken(
        address receiver,
        address market,
        uint256 netLpToRemove,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netScyFee);
}
