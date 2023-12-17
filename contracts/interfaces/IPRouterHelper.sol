// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../router/base/MarketApproxLib.sol";
import "../interfaces/IPAllActionTypeV3.sol";

interface IPRouterHelper {
    /**
     * @param output This output struct should be filled the same way as the normal removeLiquiditySingleToken
     *  operation (This means PendleSwap still works the same way). Note that the
     *  output.tokenOut will also be used as the input token for the addLiquidity
     */
    struct RemoveLiquiditySingleTokenStruct {
        address market;
        uint256 netLpToRemove;
        bool doRedeemRewards;
        TokenOutput output;
    }

    /**
     * @param guessNetTokenIn the predicted amount of tokenIn that will be used to add liquidity. This
     *  should be the same amount that was used to generate guessPtReceivedFromSy (if any).
     * @param guessPtReceivedFromSy the same guess struct in the normal addLiquiditySingleToken operation.
     *  Again, note that this struct, if not empty (i.e. if guessOffchain == 0), should be generated
     *  using `guessNetTokenIn` amount of tokenIn
     * @dev tokenIn is the output.tokenOut of the removeLiquiditySingleTokenStruct
     */
    struct AddLiquiditySingleTokenStruct {
        address market;
        uint256 minLpOut;
        uint256 guessNetTokenIn;
        ApproxParams guessPtReceivedFromSy;
    }

    /**
     * @dev tokenIn is the output.tokenOut of the removeLiquiditySingleTokenStruct
     */
    struct AddLiquiditySingleTokenKeepYtStruct {
        address market;
        uint256 minLpOut;
        uint256 minYtOut;
    }

    struct RemoveLiquiditySingleSyStruct {
        address market;
        uint256 netLpToRemove;
        bool doRedeemRewards;
    }

    /**
     * @dev guessNetSyIn & guessPtReceivedFromSy have similar meanings to AddLiquiditySingleTokenStruct
     */
    struct AddLiquiditySingleSyStruct {
        address market;
        uint256 minLpOut;
        uint256 guessNetSyIn;
        ApproxParams guessPtReceivedFromSy;
    }

    struct AddLiquiditySingleSyKeepYtStruct {
        address market;
        uint256 minLpOut;
        uint256 minYtOut;
    }

    event RemoveLiquiditySingleToken(
        address indexed caller,
        address indexed market,
        address indexed token,
        address receiver,
        uint256 netLpToRemove,
        uint256 netTokenOut
    );

    event RemoveLiquiditySingleSy(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 netLpToRemove,
        uint256 netSyOut
    );

    event AddLiquiditySingleToken(
        address indexed caller,
        address indexed market,
        address indexed token,
        address receiver,
        uint256 netTokenIn,
        uint256 netLpOut
    );

    event AddLiquiditySingleSy(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 netSyIn,
        uint256 netLpOut
    );

    event AddLiquiditySingleTokenKeepYt(
        address indexed caller,
        address indexed market,
        address indexed token,
        address receiver,
        uint256 netTokenIn,
        uint256 netLpOut,
        uint256 netYtOut
    );

    event AddLiquiditySingleSyKeepYt(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 netSyIn,
        uint256 netLpOut,
        uint256 netYtOut
    );

    function transferLiquidityDifferentSyNormal(
        RemoveLiquiditySingleTokenStruct calldata fromMarket,
        AddLiquiditySingleTokenStruct calldata toMarket
    ) external returns (uint256 netLpOut, uint256 netTokenZapIn, uint256 netSyFeeOfRemove, uint256 netSyFeeOfAdd);

    function transferLiquidityDifferentSyKeepYt(
        RemoveLiquiditySingleTokenStruct calldata fromMarket,
        AddLiquiditySingleTokenKeepYtStruct calldata toMarket
    ) external returns (uint256 netLpOut, uint256 netYtOut, uint256 netTokenZapIn, uint256 netSyFeeOfRemove);

    function transferLiquiditySameSyNormal(
        RemoveLiquiditySingleSyStruct calldata fromMarket,
        AddLiquiditySingleSyStruct calldata toMarket
    ) external returns (uint256 netLpOut, uint256 netSyZapIn, uint256 netSyFeeOfRemove, uint256 netSyFeeOfAdd);

    function transferLiquiditySameSyKeepYt(
        RemoveLiquiditySingleSyStruct calldata fromMarket,
        AddLiquiditySingleSyKeepYtStruct calldata toMarket
    ) external returns (uint256 netLpOut, uint256 netYtOut, uint256 netSyZapIn, uint256 netSyFeeOfRemove);

    function removeLiquiditySingleToken(
        RemoveLiquiditySingleTokenStruct calldata fromMarket
    ) external returns (uint256 netTokenOut, uint256 netSyFee);

    function removeLiquiditySingleSy(
        RemoveLiquiditySingleSyStruct calldata fromMarket
    ) external returns (uint256 netSyOut, uint256 netSyFee);
}
