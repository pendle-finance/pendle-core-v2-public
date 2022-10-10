// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./PendleConvexLPSY.sol";
import "../Pendle3CrvHelper.sol";
import "../../../../libraries/ArrayLib.sol";

contract Pendle3CrvAndTokenSY is PendleConvexLPSY {
    using ArrayLib for address[];

    uint256 public immutable indexOf3Crv;
    uint256 public immutable indexOfOther;
    address public immutable otherToken;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _cvxPid,
        address _crvLp,
        address _crvPool
    ) PendleConvexLPSY(_name, _symbol, _cvxPid, _crvLp, _crvPool) {
        indexOf3Crv = ICrvPool(_crvPool).coins(0) == Pendle3CrvHelper.LP ? 0 : 1;
        indexOfOther = 1 - indexOf3Crv;
        otherToken = ICrvPool(_crvPool).coins(indexOfOther);

        _safeApproveInf(Pendle3CrvHelper.LP, crvPool);
        _safeApproveInf(otherToken, crvPool);

        _safeApproveInf(Pendle3CrvHelper.DAI, Pendle3CrvHelper.POOL);
        _safeApproveInf(Pendle3CrvHelper.USDC, Pendle3CrvHelper.POOL);
        _safeApproveInf(Pendle3CrvHelper.USDT, Pendle3CrvHelper.POOL);
    }

    function _depositToCurve(address tokenIn, uint256 amountTokenToDeposit)
        internal
        virtual
        override
        returns (uint256 amountLpOut)
    {
        uint256 preBalanceLp = _selfBalance(crvLp);

        uint256[2] memory amounts;

        if (Pendle3CrvHelper.is3CrvToken(tokenIn)) {
            uint256 amount3CrvLp = Pendle3CrvHelper.deposit3Crv(tokenIn, amountTokenToDeposit);
            amounts[indexOf3Crv] = amount3CrvLp;
        } else {
            // one of the 2 LP
            amounts[_getIndex(tokenIn)] = amountTokenToDeposit;
        }

        ICrvPool(crvPool).add_liquidity(amounts, 0);

        amountLpOut = _selfBalance(crvLp) - preBalanceLp;
    }

    function _redeemFromCurve(address tokenOut, uint256 amountLpToRedeem)
        internal
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        address tokenToRemove = (tokenOut == otherToken) ? otherToken : Pendle3CrvHelper.LP;

        uint256 preBalanceToken = _selfBalance(tokenToRemove);

        ICrvPool(crvPool).remove_liquidity_one_coin(
            amountLpToRedeem,
            Math.Int128(_getIndex(tokenToRemove)),
            0
        );

        uint256 amountTokenRemoved = _selfBalance(tokenToRemove) - preBalanceToken;

        if (Pendle3CrvHelper.is3CrvToken(tokenOut)) {
            amountTokenOut = Pendle3CrvHelper.redeem3Crv(tokenOut, amountTokenRemoved);
        } else {
            // one of the 2 LP
            amountTokenOut = amountTokenRemoved;
        }
    }

    function _previewDepositToCurve(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        uint256[2] memory amounts;

        if (Pendle3CrvHelper.is3CrvToken(tokenIn)) {
            uint256 amount3CrvLp = Pendle3CrvHelper.preview3CrvDeposit(
                tokenIn,
                amountTokenToDeposit
            );
            amounts[indexOf3Crv] = amount3CrvLp;
        } else {
            // one of the 2 LP
            amounts[_getIndex(tokenIn)] = amountTokenToDeposit;
        }

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

        if (Pendle3CrvHelper.is3CrvToken(tokenOut)) {
            return Pendle3CrvHelper.preview3CrvRedeem(tokenOut, amountTokenRemoved);
        } else {
            // one of the 2 LP
            return amountTokenRemoved;
        }
    }

    function _getIndex(address token) internal view returns (uint256) {
        if (token == Pendle3CrvHelper.LP || Pendle3CrvHelper.is3CrvToken(token)) {
            return indexOf3Crv;
        } else {
            return indexOfOther;
        }
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](6);
        res[0] = crvLp;
        res[1] = otherToken;
        res[2] = Pendle3CrvHelper.LP;
        res[3] = Pendle3CrvHelper.DAI;
        res[4] = Pendle3CrvHelper.USDC;
        res[5] = Pendle3CrvHelper.USDT;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](6);
        res[0] = crvLp;
        res[1] = otherToken;
        res[2] = Pendle3CrvHelper.LP;
        res[3] = Pendle3CrvHelper.DAI;
        res[4] = Pendle3CrvHelper.USDC;
        res[5] = Pendle3CrvHelper.USDT;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool res) {
        res = (token == crvLp ||
            token == otherToken ||
            token == Pendle3CrvHelper.LP ||
            Pendle3CrvHelper.is3CrvToken(token));
    }

    function isValidTokenOut(address token) public view override returns (bool res) {
        res = (token == crvLp ||
            token == otherToken ||
            token == Pendle3CrvHelper.LP ||
            Pendle3CrvHelper.is3CrvToken(token));
    }
}
