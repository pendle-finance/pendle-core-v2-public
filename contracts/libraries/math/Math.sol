// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.9;

import "./LogExpMath.sol";

/* solhint-disable private-vars-leading-underscore, reason-string */

library Math {
    uint256 internal constant ONE = 1e18; // 18 decimal places
    int256 internal constant IONE = 1e18; // 18 decimal places

    uint256 internal constant MAX_POW_RELATIVE_ERROR = 10000; // 10^(-14)

    function subMax0(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            return (a >= b ? a - b : 0);
        }
    }

    function subNoNeg(int256 a, int256 b) internal pure returns (int256) {
        require(a >= b, "NEGATIVE");
        unchecked {
            return a - b;
        }
    }

    function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 product = a * b;
        unchecked {
            return product / ONE;
        }
    }

    function mulDown(int256 a, int256 b) internal pure returns (int256) {
        int256 product = a * b;
        unchecked {
            return product / IONE;
        }
    }

    function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 aInflated = a * ONE;
        unchecked {
            return aInflated / b;
        }
    }

    function divDown(int256 a, int256 b) internal pure returns (int256) {
        int256 aInflated = a * IONE;
        unchecked {
            return aInflated / b;
        }
    }

    function abs(int256 x) internal pure returns (uint256) {
        return uint256(x > 0 ? x : -x);
    }

    function neg(int256 x) internal pure returns (int256) {
        return -x;
    }

    function neg(uint256 x) internal pure returns (int256) {
        return -Int(x);
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x > y ? x : y);
    }

    function max(int256 x, int256 y) internal pure returns (int256) {
        return (x > y ? x : y);
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x < y ? x : y);
    }

    function min(int256 x, int256 y) internal pure returns (int256) {
        return (x < y ? x : y);
    }

    function Uint(int256 x) internal pure returns (uint256) {
        require(x >= 0);
        return uint256(x);
    }

    function Int(uint256 x) internal pure returns (int256) {
        require(x < (1 << 255)); // signed, lim = bit-1
        return int256(x);
    }

    function Int128(int256 x) internal pure returns (int128) {
        require(x < (1 << 127)); // signed, lim = bit-1
        return int128(x);
    }

    function Uint32(uint256 x) internal pure returns (uint32) {
        require(x < (1 << 32)); // unsigned, lim = bit
        return uint32(x);
    }

    function Uint112(uint256 x) internal pure returns (uint112) {
        require(x < (1 << 112)); // unsigned, lim = bit
        return uint112(x);
    }

    function isAApproxB(
        uint256 a,
        uint256 b,
        uint256 eps
    ) internal pure returns (bool) {
        return (isAGreaterApproxB(a, b, eps) || isASmallerApproxB(a, b, eps));
    }

    function isAGreaterApproxB(
        uint256 a,
        uint256 b,
        uint256 eps
    ) internal pure returns (bool) {
        return a >= b && a <= mulDown(b, Math.ONE + eps);
    }

    function isASmallerApproxB(
        uint256 a,
        uint256 b,
        uint256 eps
    ) internal pure returns (bool) {
        return a <= b && a >= mulDown(b, Math.ONE - eps);
    }
}
