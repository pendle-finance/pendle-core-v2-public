// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPPostPtLoopStateChecker} from "../interfaces/IPPostPtLoopStateChecker.sol";
import {IPLoopPositionBox} from "../interfaces/IPLoopPositionBox.sol";
import {IMoneyMarket, MarketCtx} from "../interfaces/IMoneyMarket.sol";
import {TokenHelper} from "../core/libraries/TokenHelper.sol";

contract PostPtLoopStateChecker is IPPostPtLoopStateChecker, TokenHelper {
    struct BalanceCheck {
        address token;
        uint256 lowerBound;
        uint256 upperBound;
    }

    struct StateCheck {
        BalanceCheck[] boxBalances;
        BalanceCheck[] ownerBalances;
    }

    /// @dev Money market balances, read once per `check`. `valid` is false with no money market on this chain;
    /// then `MM_COLAT` / `MM_DEBT` read a plain token balance.
    struct MMBalances {
        bool valid;
        uint256 colat;
        uint256 debt;
    }

    address public constant MM_COLAT = address(1);
    address public constant MM_DEBT = address(2);

    /// @notice Not `view`: `collateralBalance` and `debtBalance` are not.
    function check(MarketCtx memory ctx, bytes calldata data) external {
        StateCheck memory stateCheck = abi.decode(data, (StateCheck));
        IPLoopPositionBox box = ctx.box;

        MMBalances memory mm;
        address spokeMM = box.SPOKE_MONEY_MARKET();
        if (spokeMM != address(0)) {
            mm = MMBalances({
                valid: true,
                colat: IMoneyMarket(spokeMM).collateralBalance(ctx),
                debt: IMoneyMarket(spokeMM).debtBalance(ctx)
            });
        }
        _checkBalances(address(box), stateCheck.boxBalances, mm);

        if (stateCheck.ownerBalances.length > 0) {
            _checkBalances(box.OWNER(), stateCheck.ownerBalances, MMBalances(false, 0, 0));
        }
    }

    function _checkBalances(address acc, BalanceCheck[] memory checks, MMBalances memory mm) internal view {
        for (uint256 i = 0; i < checks.length; i++) {
            address token = checks[i].token;
            uint256 bal;
            if (token == MM_COLAT && mm.valid) {
                bal = mm.colat;
            } else if (token == MM_DEBT && mm.valid) {
                bal = mm.debt;
            } else {
                bal = _balanceOf(acc, token);
            }

            require(
                bal >= checks[i].lowerBound && bal <= checks[i].upperBound, "LoopStateChecker: balance check failed"
            );
        }
    }
}
