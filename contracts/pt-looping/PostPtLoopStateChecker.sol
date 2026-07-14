// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPPostPtLoopStateChecker} from "../interfaces/IPPostPtLoopStateChecker.sol";
import {IPLoopPositionBox, BoxData} from "../interfaces/IPLoopPositionBox.sol";
import {IPLoopPositionBoxFactory} from "../interfaces/IPLoopPositionBoxFactory.sol";
import {IMoneyMarket, MarketCtx, createMarketCtx} from "../interfaces/IMoneyMarket.sol";
import {TokenHelper} from "../core/libraries/TokenHelper.sol";

contract PostPtLoopStateChecker is IPPostPtLoopStateChecker, TokenHelper {
    IPLoopPositionBoxFactory public immutable BOX_FACTORY;

    constructor(address boxFactory) {
        BOX_FACTORY = IPLoopPositionBoxFactory(boxFactory);
    }

    struct BalanceCheck {
        address token;
        uint256 lowerBound;
        uint256 upperBound;
    }

    struct StateCheck {
        BalanceCheck[] boxBalances;
        BalanceCheck[] ownerBalances;
    }

    /// @dev MM collateral/debt balances, resolved once per `check`. `valid` is false when the box has
    /// no spoke money market on this chain; `MM_COLAT`/`MM_DEBT` checks then fall through to a raw
    /// token balance read, exactly as the prior `withMMBalances` flag did.
    struct MMBalances {
        bool valid;
        uint256 colat;
        uint256 debt;
    }

    address public constant MM_COLAT = address(1);
    address public constant MM_DEBT = address(2);

    /// @notice non-view, as `collateralBalance` and `debtBalance` are non-view
    function check(IPLoopPositionBox box, bytes calldata data) external {
        StateCheck memory stateCheck = abi.decode(data, (StateCheck));

        MMBalances memory mm; // valid == false until a spoke MM is found
        address spokeMM = box.SPOKE_MONEY_MARKET();
        if (spokeMM != address(0)) {
            BoxData memory boxData = BOX_FACTORY.boxData(box.BOX_ID());
            MarketCtx memory mctx = createMarketCtx(box, boxData);
            mm = MMBalances({
                valid: true,
                colat: IMoneyMarket(spokeMM).collateralBalance(mctx),
                debt: IMoneyMarket(spokeMM).debtBalance(mctx)
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
