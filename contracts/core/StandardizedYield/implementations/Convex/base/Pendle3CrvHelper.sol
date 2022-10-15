// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../../../../interfaces/Curve/ICrvPool.sol";
import "../../../../libraries/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library Pendle3CrvHelper {
    using Math for uint256;

    address public constant LP = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
    address public constant POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    function preview3CrvDeposit(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        returns (uint256)
    {
        return
            ICrvPool(POOL).calc_token_amount(
                _getTokenAmounts(tokenIn, amountTokenToDeposit),
                true
            );
    }

    function preview3CrvRedeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        view
        returns (uint256)
    {
        return
            ICrvPool(POOL).calc_withdraw_one_coin(
                amountSharesToRedeem,
                _get3CrvTokenIndex(tokenOut).Int128()
            );
    }

    function deposit3Crv(address tokenIn, uint256 amountTokenToDeposit)
        internal
        returns (uint256)
    {
        uint256 balBefore = IERC20(LP).balanceOf(address(this));
        ICrvPool(POOL).add_liquidity(_getTokenAmounts(tokenIn, amountTokenToDeposit), 0);
        uint256 balAfter = IERC20(LP).balanceOf(address(this));
        return balAfter - balBefore;
    }

    function redeem3Crv(address tokenOut, uint256 amountSharesToRedeem)
        internal
        returns (uint256)
    {
        uint256 balBefore = IERC20(tokenOut).balanceOf(address(this));
        ICrvPool(POOL).remove_liquidity_one_coin(
            amountSharesToRedeem,
            _get3CrvTokenIndex(tokenOut).Int128(),
            0
        );
        uint256 balAfter = IERC20(tokenOut).balanceOf(address(this));
        return balAfter - balBefore;
    }

    function _getTokenAmounts(address token, uint256 amount)
        internal
        pure
        returns (uint256[3] memory res)
    {
        res[_get3CrvTokenIndex(token)] = amount;
    }

    function _get3CrvTokenIndex(address token) internal pure returns (uint256) {
        if (token == DAI) return 0;
        if (token == USDC) return 1;
        if (token == USDT) return 2;
        revert("Pendle3CrvHelper: not valid token");
    }

    function is3CrvToken(address token) internal pure returns (bool) {
        return (token == DAI || token == USDC || token == USDT);
    }
}
