// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./PendlePumpHelperLib.sol";
import "../../SYBase.sol";

contract PendlePumpBTCSY is SYBase {
    address public constant WBTC = PendlePumpHelperLib.WBTC;
    address public constant PUMP_BTC = PendlePumpHelperLib.PUMP_BTC;

    constructor() SYBase("SY pumpBTC", "SY-pumpBTC", PUMP_BTC) {
        _safeApproveInf(WBTC, PendlePumpHelperLib.PUMP_STAKING);
    }

    function _deposit(address tokenIn, uint256 amountDeposited) internal virtual override returns (uint256) {
        if (tokenIn != PUMP_BTC) {
            PendlePumpHelperLib._mintPumpBTC(amountDeposited);
        }
        return amountDeposited;
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        if (tokenOut == PUMP_BTC) {
            _transferOut(tokenOut, receiver, amountSharesToRedeem);
            return amountSharesToRedeem;
        } else {
            // must be WBTC
            PendlePumpHelperLib._instantUnstake(amountSharesToRedeem);
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

    function _previewDeposit(
        address /*tokenIn*/,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 /*amountSharesOut*/) {
        return amountTokenToDeposit;
    }

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

    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, WBTC, IERC20Metadata(WBTC).decimals());
    }
}
