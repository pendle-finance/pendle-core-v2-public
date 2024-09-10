// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./PendleCornBaseSYUpg.sol";
import "../Solv/PendleSolvHelper.sol";

contract PendleCornSolvBTCBBNSYUpg is PendleCornBaseSYUpg {

    address public constant WBTC = PendleSolvHelper.WBTC;
    address public constant SOLV_BTC = PendleSolvHelper.SOLV_BTC_TOKEN;
    address public constant SOLV_BTCBBN = PendleSolvHelper.SOLV_BTCBBN_TOKEN;

    constructor() PendleCornBaseSYUpg(SOLV_BTCBBN, WBTC) {}

    function initialize(address _initialExchangeRateOracle) external initializer {
        _safeApproveInf(WBTC, PendleSolvHelper.SOLV_BTC_ROUTER);
        _safeApproveInf(SOLV_BTC, PendleSolvHelper.SOLV_BTCBBN_ROUTER);
        __CornBaseSY_init_("SY Corn Solv BTC-BBN", "SY-corn-solvBTCBBN", _initialExchangeRateOracle);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn != SOLV_BTCBBN) {
            amountDeposited = PendleSolvHelper._mintBTCBBN(tokenIn, amountDeposited);
        }
        return ICornSilo(CORN_SILO).deposit(depositToken, amountDeposited);
    }
}