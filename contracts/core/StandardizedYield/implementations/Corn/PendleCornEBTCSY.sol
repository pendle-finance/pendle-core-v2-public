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
    address public constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address public constant wBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant LBTC = 0x8236a87084f8B84306f72007F36F2618A5634494;
    address public constant vedaTeller = 0x458797A320e6313c980C2bC7D270466A6288A8bB;

    uint256 public constant ONE_SHARE = 10 ** 8;
    uint256 public constant PREMIUM_SHARE_BPS = 10 ** 4;
    address public constant ONERACLE = 0x1F0318B5Ab2c4084692986A2C25916Cec1195cD9;

    address public immutable vedaAccountant;

    constructor() PendleCornBaseSYUpg(eBTC, wBTC) {
        vedaAccountant = IVedaTeller(vedaTeller).accountant();
    }

    function initialize() external initializer {
        _safeApproveInf(cbBTC, eBTC);
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

        IVedaTeller.Asset memory data = IVedaTeller(vedaTeller).assetData(tokenIn);
        amountSharesOut = amountSharesOut * (PREMIUM_SHARE_BPS - data.sharePremium) / PREMIUM_SHARE_BPS;
    }

    function isValidTokenIn(address token) public pure override returns (bool) {
        return token == eBTC || token == wBTC || token == cbBTC || token == LBTC;
    }

    function getTokensIn() public pure override returns (address[] memory res) {
        return ArrayLib.create(wBTC, cbBTC, eBTC, LBTC);
    }
}
