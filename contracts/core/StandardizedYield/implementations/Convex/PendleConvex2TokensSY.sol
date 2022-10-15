// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./base/PendleConvexLPSY.sol";
import "../../../libraries/ArrayLib.sol";

contract PendleConvex2TokensSY is PendleConvexLPSY {
    using ArrayLib for address[];

    address public immutable token0;
    address public immutable token1;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _cvxPid,
        address _crvLp,
        address _crvPool
    ) PendleConvexLPSY(_name, _symbol, _cvxPid, _crvLp, _crvPool) {
        token0 = ICrvPool(_crvPool).coins(0);
        token1 = ICrvPool(_crvPool).coins(1);

        _safeApproveInf(token0, crvPool);
        _safeApproveInf(token1, crvPool);
    }

    function _depositToCurve(address tokenIn, uint256 amountTokenToDeposit)
        internal
        virtual
        override
        returns (uint256 amountLpOut)
    {
        uint256 preBalanceLp = _selfBalance(crvLp);

        uint256[2] memory amounts;

        amounts[_getIndex(tokenIn)] = amountTokenToDeposit;

        ICrvPool(crvPool).add_liquidity(amounts, 0);

        amountLpOut = _selfBalance(crvLp) - preBalanceLp;
    }

    function _redeemFromCurve(address tokenOut, uint256 amountLpToRedeem)
        internal
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        uint256 preBalanceToken = _selfBalance(tokenOut);

        ICrvPool(crvPool).remove_liquidity_one_coin(
            amountLpToRedeem,
            Math.Int128(_getIndex(tokenOut)),
            0
        );

        amountTokenOut = _selfBalance(tokenOut) - preBalanceToken;
    }

    function _previewDepositToCurve(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        uint256[2] memory amounts;

        amounts[_getIndex(tokenIn)] = amountTokenToDeposit;

        return ICrvPool(crvPool).calc_token_amount(amounts, true);
    }

    function _previewRedeemFromCurve(address tokenOut, uint256 amountLpToRedeem)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        uint256 amountTokenRemoved = ICrvPool(crvPool).calc_withdraw_one_coin(
            amountLpToRedeem,
            Math.Int128(_getIndex(tokenOut))
        );

        return amountTokenRemoved;
    }

    function _getIndex(address token) internal view returns (uint256) {
        return (token == token0 ? 0 : 1);
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](3);
        res[0] = crvLp;
        res[1] = token0;
        res[2] = token1;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](3);
        res[0] = crvLp;
        res[1] = token0;
        res[2] = token1;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool res) {
        res = (token == crvLp || token == token0 || token == token1);
    }

    function isValidTokenOut(address token) public view override returns (bool res) {
        res = (token == crvLp || token == token0 || token == token1);
    }
}
