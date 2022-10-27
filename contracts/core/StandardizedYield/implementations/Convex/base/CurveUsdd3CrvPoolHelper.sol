// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../../../libraries/math/Math.sol";
import "../../../../../interfaces/Curve/ICrvPool.sol";
import "./Curve3CrvPoolHelper.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library CurveUsdd3CrvPoolHelper {
    using Math for uint256;

    uint256 public constant N_COINS = 2;
    uint256 public constant A_PRECISION = 100;
    uint256 public constant PRECISION = 10**18;
    uint256 public constant RATE_0 = 10**18;
    uint256 public constant FEE_DENOMINATOR = 10**10;

    // LP == POOL
    address public constant POOL = 0xe6b5CC1B4b47305c58392CE3D359B10282FC36Ea;
    address public constant USDD = 0x0C10bF8FcB7Bf5412187A595ab97a3609160b5c6;
    address public constant LP_3CRV = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;

    function previewAddLiquidity(address token, uint256 amount)
        internal
        view
        returns (uint256)
    {

        uint256 RATE_1 = Curve3CrvPoolHelper.get_virtual_price();
        if (Curve3CrvPoolHelper.is3CrvToken(token)) {
            (amount, RATE_1) = Curve3CrvPoolHelper.preview3CrvDeposit(token, amount);
            token = LP_3CRV;
        }

        uint256[N_COINS] memory _amounts = _getTokenAmounts(token, amount);

        uint256 amp = ICrvPool(POOL).A_precise();
        uint256[N_COINS] memory old_balances = _getBalances();
        uint256[N_COINS] memory new_balances;
        memcpy(new_balances, old_balances);

        uint256 D0 = _get_D_mem(old_balances, amp, RATE_1);
        uint256 total_supply = IERC20(POOL).totalSupply();


        for (uint256 i = 0; i < N_COINS; ++i) {
            // skip totalSupply = 0 check
            new_balances[i] += _amounts[i];
        }

        uint256 D1 = _get_D_mem(new_balances, amp, RATE_1);
        assert(D1 > D0);

        uint256[N_COINS] memory fees;

        // skip total_supply > 0 check
        uint256 fee = (ICrvPool(POOL).fee() * N_COINS) / (4 * (N_COINS - 1));
        for (uint256 i = 0; i < N_COINS; ++i) {
            uint256 ideal_balance = (D1 * old_balances[i]) / D0;
            uint256 difference = 0;
            uint256 new_balance = new_balances[i];

            if (ideal_balance > new_balance) {
                difference = ideal_balance - new_balance;
            } else {
                difference = new_balance - ideal_balance;
            }
            fees[i] = (fee * difference) / FEE_DENOMINATOR;
            new_balances[i] -= fees[i];
        }
        uint256 D2 = _get_D_mem(new_balances, amp, RATE_1);
        return (total_supply * (D2 - D0)) / D0;
    }

    function _get_D_mem(uint256[N_COINS] memory balances, uint256 _amp, uint256 RATE_1)
        internal
        pure
        returns (uint256)
    {
        uint256[N_COINS] memory _xp;
        _xp[0] = (RATE_0 * balances[0]) / PRECISION;
        _xp[1] = (RATE_1 * balances[1]) / PRECISION;

        return _get_D(_xp, _amp);
    }

    function _get_D(uint256[N_COINS] memory _xp, uint256 _amp) internal pure returns (uint256) {
        uint256 S = 0;
        uint256 Dprev = 0;

        for (uint256 k = 0; k < N_COINS; ++k) {
            S += _xp[k];
        }
        if (S == 0) return 0;

        uint256 D = S;
        uint256 Ann = _amp * N_COINS;

        for (uint256 _i = 0; _i < 255; ++_i) {
            uint256 D_P = D;
            for (uint256 k = 0; k < N_COINS; ++k) {
                D_P = (D_P * D) / (_xp[k] * N_COINS);
            }
            Dprev = D;
            D =
                (((Ann * S) / A_PRECISION + D_P * N_COINS) * D) /
                (((Ann - A_PRECISION) * D) / A_PRECISION + (N_COINS + 1) * D_P);

            if (D > Dprev) {
                if (D - Dprev <= 1) {
                    return D;
                }
            } else {
                if (Dprev - D <= 1) {
                    return D;
                }
            }
        }
        assert(false);
    }

    function _getBalances() internal view returns (uint256[N_COINS] memory balances) {
        balances[0] = ICrvPool(POOL).balances(0);
        balances[1] = ICrvPool(POOL).balances(1);
    }

    function memcpy(uint256[N_COINS] memory a, uint256[N_COINS] memory b) internal pure {
        for (uint256 i = 0; i < N_COINS; ++i) {
            a[i] = b[i];
        }
    }

    function _getTokenAmounts(address token, uint256 amount)
        internal
        pure
        returns (uint256[N_COINS] memory res)
    {
        res[token == USDD ? 0 : 1] = amount;
    }
}
