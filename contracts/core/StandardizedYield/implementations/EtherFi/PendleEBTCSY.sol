// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "../PendleERC20SYUpg.sol";
import "../../../../interfaces/EtherFi/IVedaTeller.sol";
import "../../../../interfaces/EtherFi/IVedaAccountant.sol";

contract PendleEBTCSY is PendleERC20SYUpg {
    // solhint-disable immutable-vars-naming
    // solhint-disable const-name-snakecase
    // solhint-disable ordering

    address public constant eBTC = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642;
    address public constant tBTC = 0x18084fbA666a33d37592fA2633fD49a74DD93a88;
    address public constant wBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant LBTC = 0x8236a87084f8B84306f72007F36F2618A5634494;
    address public constant vedaTeller = 0xe19a43B1b8af6CeE71749Af2332627338B3242D1;

    uint256 public constant ONE_SHARE = 10 ** 8;

    address public immutable vedaAccountant;

    constructor() PendleERC20SYUpg(eBTC) {
        vedaAccountant = IVedaTeller(vedaTeller).accountant();
    }

    function approveAllForTeller() external {
        _safeApproveInf(tBTC, eBTC);
        _safeApproveInf(wBTC, eBTC);
        _safeApproveInf(LBTC, eBTC);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == eBTC) {
            return amountDeposited;
        }
        return IVedaTeller(vedaTeller).bulkDeposit(tokenIn, amountDeposited, 0, address(this));
    }

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
