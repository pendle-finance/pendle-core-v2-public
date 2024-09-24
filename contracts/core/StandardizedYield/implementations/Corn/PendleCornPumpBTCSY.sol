// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./PendleCornBaseSY.sol";
import "../Pump/PendlePumpHelperLib.sol";

contract PendleCornPumpBTCSY is PendleCornBaseSY {
    address public constant WBTC = PendlePumpHelperLib.WBTC;
    address public constant PUMP_BTC = PendlePumpHelperLib.PUMP_BTC;

    constructor() PendleCornBaseSY("SY Corn pumpBTC", "SY-corn-pumpBTC", PUMP_BTC, WBTC, address(0)) {
        _safeApproveInf(WBTC, PendlePumpHelperLib.PUMP_STAKING);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address tokenIn, uint256 amountDeposited) internal virtual override returns (uint256) {
        if (tokenIn != PUMP_BTC) {
            PendlePumpHelperLib._mintPumpBTC(amountDeposited);
        }
        return ICornSilo(CORN_SILO).deposit(depositToken, amountDeposited);
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        amountTokenOut = ICornSilo(CORN_SILO).redeemToken(depositToken, amountSharesToRedeem);

        if (tokenOut == PUMP_BTC) {
            _transferOut(depositToken, receiver, amountTokenOut);
        } else {
            // must be WBTC
            PendlePumpHelperLib._instantUnstake(amountTokenOut);
            amountTokenOut = _selfBalance(WBTC);
            _transferOut(WBTC, receiver, amountTokenOut);
        }
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return PMath.ONE;
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewRedeem(
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal view override returns (uint256 amountTokenOut) {
        if (tokenOut == PUMP_BTC) {
            return amountSharesToRedeem;
        }
        return PendlePumpHelperLib._previewInstantUnstake(amountSharesToRedeem);
    }

    function getTokensIn() public view virtual override returns (address[] memory) {
        return ArrayLib.create(WBTC, PUMP_BTC);
    }

    function getTokensOut() public view virtual override returns (address[] memory) {
        return ArrayLib.create(WBTC, PUMP_BTC);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == WBTC || token == PUMP_BTC;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == WBTC || token == PUMP_BTC;
    }
}
