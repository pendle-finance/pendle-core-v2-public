// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./TokenUtilsLib.sol";
import "../math/FixedPoint.sol";
import "openzeppelin-solidity/contracts/utils/math/Math.sol";

struct TrioBools {
    bool boolA;
    bool boolB;
    bool boolC;
}

struct TrioUints {
    uint256 uintA;
    uint256 uintB;
    uint256 uintC;
}

struct TrioTokens {
    address tokenA;
    address tokenB;
    address tokenC;
}

struct TrioTokenUints {
    TrioTokens tokens;
    TrioUints uints;
}

library TrioTokensLib {
    using Math for uint256;
    using FixedPoint for uint256;
    using TokenUtils for IERC20;

    address internal constant ZERO = address(0);

    function safeTransferFrom(
        TrioTokens memory tokens,
        address from,
        address to,
        TrioUints memory amounts
    ) internal {
        if (tokens.tokenA != ZERO && amounts.uintA != 0)
            IERC20(tokens.tokenA).safeTransferFrom(from, to, amounts.uintA);
        if (tokens.tokenB != ZERO && amounts.uintB != 0)
            IERC20(tokens.tokenB).safeTransferFrom(from, to, amounts.uintB);
        if (tokens.tokenC != ZERO && amounts.uintC != 0)
            IERC20(tokens.tokenC).safeTransferFrom(from, to, amounts.uintC);
    }

    function safeTransfer(
        TrioTokens memory tokens,
        address to,
        TrioUints memory amounts
    ) internal {
        if (tokens.tokenA != ZERO && amounts.uintA != 0)
            IERC20(tokens.tokenA).safeTransfer(to, amounts.uintA);
        if (tokens.tokenB != ZERO && amounts.uintB != 0)
            IERC20(tokens.tokenB).safeTransfer(to, amounts.uintB);
        if (tokens.tokenC != ZERO && amounts.uintC != 0)
            IERC20(tokens.tokenC).safeTransfer(to, amounts.uintC);
    }

    function infinityApprove(TrioTokens memory tokens, address to) internal {
        if (tokens.tokenA != ZERO) IERC20(tokens.tokenA).safeApprove(to, type(uint256).max);
        if (tokens.tokenB != ZERO) IERC20(tokens.tokenB).safeApprove(to, type(uint256).max);
        if (tokens.tokenC != ZERO) IERC20(tokens.tokenC).safeApprove(to, type(uint256).max);
    }

    function allowance(TrioTokens memory tokens, address spender)
        internal
        view
        returns (TrioUints memory res)
    {
        if (tokens.tokenA != ZERO)
            res.uintA = IERC20(tokens.tokenA).allowance(address(this), spender);
        if (tokens.tokenB != ZERO)
            res.uintB = IERC20(tokens.tokenB).allowance(address(this), spender);
        if (tokens.tokenC != ZERO)
            res.uintC = IERC20(tokens.tokenC).allowance(address(this), spender);
    }

    function balanceOf(TrioTokens memory tokens, address account)
        internal
        view
        returns (TrioUints memory balances)
    {
        if (tokens.tokenA != ZERO) balances.uintA = IERC20(tokens.tokenA).balanceOf(account);
        if (tokens.tokenB != ZERO) balances.uintB = IERC20(tokens.tokenB).balanceOf(account);
        if (tokens.tokenC != ZERO) balances.uintC = IERC20(tokens.tokenC).balanceOf(account);
    }

    function verify(TrioTokens memory a) internal pure {
        if (a.tokenA != ZERO)
            require(a.tokenA != a.tokenB && a.tokenA != a.tokenC, "DUPLICATED_TOKENS");
        if (a.tokenB != ZERO) require(a.tokenB != a.tokenC, "DUPLICATED_TOKENS");
    }

    function add(TrioUints memory a, TrioUints memory b)
        internal
        pure
        returns (TrioUints memory res)
    {
        res.uintA = a.uintA + b.uintA;
        res.uintB = a.uintB + b.uintB;
        res.uintC = a.uintC + b.uintC;
    }

    function sub(TrioUints memory a, TrioUints memory b)
        internal
        pure
        returns (TrioUints memory res)
    {
        res.uintA = a.uintA - b.uintA;
        res.uintB = a.uintB - b.uintB;
        res.uintC = a.uintC - b.uintC;
    }

    function eq(TrioUints memory a, TrioUints memory b) internal pure returns (bool) {
        return a.uintA == b.uintA && a.uintB == b.uintB && a.uintC == b.uintC;
    }

    function min(TrioUints memory a, TrioUints memory b) internal pure returns (TrioUints memory) {
        return
            TrioUints(
                Math.min(a.uintA, b.uintA),
                Math.min(a.uintB, b.uintB),
                Math.min(a.uintC, b.uintC)
            );
    }

    function mulDown(TrioUints memory a, uint256 b) internal pure returns (TrioUints memory res) {
        res.uintA = a.uintA.mulDown(b);
        res.uintB = a.uintB.mulDown(b);
        res.uintC = a.uintC.mulDown(b);
    }

    function divDown(TrioUints memory a, uint256 b) internal pure returns (TrioUints memory res) {
        res.uintA = a.uintA.divDown(b);
        res.uintB = a.uintB.divDown(b);
        res.uintC = a.uintC.divDown(b);
    }

    function mul(TrioUints memory a, uint256 b) internal pure returns (TrioUints memory res) {
        res.uintA = a.uintA * b;
        res.uintB = a.uintB * b;
        res.uintC = a.uintC * b;
    }

    function div(TrioUints memory a, uint256 b) internal pure returns (TrioUints memory res) {
        res.uintA = a.uintA / b;
        res.uintB = a.uintB / b;
        res.uintC = a.uintC / b;
    }

    function allZero(TrioUints memory a) internal pure returns (bool) {
        return a.uintA == 0 && a.uintB == 0 && a.uintC == 0;
    }

    function allZero(TrioTokens memory a) internal pure returns (bool) {
        return a.tokenA == ZERO && a.tokenB == ZERO && a.tokenC == ZERO;
    }

    function contains(TrioTokens memory tokens, address _token) internal pure returns (bool) {
        if (_token == ZERO) return false;
        return (_token == tokens.tokenA || _token == tokens.tokenB || _token == tokens.tokenC);
    }

    function toArr(TrioTokens memory tokens) internal pure returns (address[] memory res) {
        res = new address[](3);
        res[0] = tokens.tokenA;
        res[1] = tokens.tokenB;
        res[2] = tokens.tokenC;
    }
}
