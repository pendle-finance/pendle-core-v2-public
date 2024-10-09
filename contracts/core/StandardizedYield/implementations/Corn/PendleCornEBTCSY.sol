// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "./PendleCornBaseSYUpg.sol";
import "../../../../interfaces/EtherFi/IVedaTeller.sol";
import "../../../../interfaces/EtherFi/IVedaAccountant.sol";

contract PendleCornEBTCSY is PendleCornBaseSYUpg {
    // solhint-disable immutable-vars-naming
    // solhint-disable const-name-snakecase
    // solhint-disable ordering
    address public constant eBTC = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642;
    address public constant tBTC = 0x18084fbA666a33d37592fA2633fD49a74DD93a88;
    address public constant wBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant LBTC = 0x8236a87084f8B84306f72007F36F2618A5634494;
    address public constant vedaTeller = 0xe19a43B1b8af6CeE71749Af2332627338B3242D1;
    address public constant ONERACLE = 0x1F0318B5Ab2c4084692986A2C25916Cec1195cD9;
    uint256 public constant ONE_SHARE = 10 ** 8;

    address public immutable vedaAccountant;

    constructor() PendleCornBaseSYUpg(eBTC, wBTC) {
        vedaAccountant = IVedaTeller(vedaTeller).accountant();
    }

    function initialize() external initializer {
        _safeApproveInf(tBTC, eBTC);
        _safeApproveInf(wBTC, eBTC);
        _safeApproveInf(LBTC, eBTC);
        __CornBaseSY_init_("SY ether.fi eBTC", "SY-corn-eBTC", ONERACLE);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address tokenIn, uint256 amountDeposited) internal virtual override returns (uint256) {
        if (tokenIn != eBTC) {
            amountDeposited = IVedaTeller(vedaTeller).bulkDeposit(tokenIn, amountDeposited, 0, address(this));
        }
        return ICornSilo(CORN_SILO).deposit(depositToken, amountDeposited);
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == eBTC) {
            return amountTokenToDeposit;
        }
        uint256 rate = IVedaAccountant(vedaAccountant).getRateInQuoteSafe(tokenIn);
        amountSharesOut = (amountTokenToDeposit * ONE_SHARE) / rate;
    }

    function isValidTokenIn(address token) public pure override returns (bool) {
        return token == eBTC || token == wBTC || token == tBTC || token == LBTC;
    }

    function getTokensIn() public pure override returns (address[] memory res) {
        return ArrayLib.create(wBTC, tBTC, eBTC, LBTC);
    }
}
