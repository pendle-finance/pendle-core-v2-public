// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "../AaveV3/PendleAaveV3WithRewardsSYUpg.sol";
import "../../../../interfaces/IPExchangeRateOracle.sol";
import "../PendleERC20SYUpg.sol";
import "../../../../interfaces/EtherFi/IVedaTeller.sol";
import "../../../../interfaces/EtherFi/IVedaAccountant.sol";
import "../../../../interfaces/Zerolend/IZerolendPool.sol";
import "../../../../interfaces/Zerolend/IZerolendZ0Token.sol";
import "../../../../interfaces/IPTokenWithSupplyCap.sol";

contract PendleZerolendEBTCSYUpg is PendleAaveV3WithRewardsSYUpg {
    // solhint-disable immutable-vars-naming
    // solhint-disable const-name-snakecase
    // solhint-disable ordering

    address public constant Z0EBTC = 0x52bB650211e8a6986287306A4c09B73A9Affd5e9;
    address public constant ZEROLEND_POOL = 0xCD2b31071119D7eA449a9D211AC8eBF7Ee97F987;
    address public constant ZEROLEND_INCENTIVE_CONTROLLER = 0x938e23c10C501CE5D42Bc516eCFDf5AbD9C51d2b; // no reward currently, leave as address(0) for gas saving
    address public constant ZERO = 0x2Da17fAf782ae884faf7dB2208BBC66b6E085C22;

    address public constant eBTC = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642;
    address public constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address public constant wBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant LBTC = 0x8236a87084f8B84306f72007F36F2618A5634494;
    address public constant vedaTeller = 0x458797A320e6313c980C2bC7D270466A6288A8bB;

    uint256 public constant ONE_SHARE = 10 ** 8;
    uint256 public constant PREMIUM_SHARE_BPS = 10 ** 4;

    address public immutable vedaAccountant;

    constructor() PendleAaveV3WithRewardsSYUpg(ZEROLEND_POOL, Z0EBTC, ZEROLEND_INCENTIVE_CONTROLLER, ZERO) {
        vedaAccountant = IVedaTeller(vedaTeller).accountant();
    }

    function approveAllForTeller() external {
        _safeApproveInf(cbBTC, eBTC);
        _safeApproveInf(wBTC, eBTC);
        _safeApproveInf(LBTC, eBTC);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn != eBTC && tokenIn != aToken) {
            (tokenIn, amountDeposited) = (
                eBTC,
                IVedaTeller(vedaTeller).bulkDeposit(tokenIn, amountDeposited, 0, address(this))
            );
        }

        return super._deposit(tokenIn, amountDeposited);
    }

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256) {
        if (tokenIn != eBTC && tokenIn != aToken) {
            uint256 rate = IVedaAccountant(vedaAccountant).getRateInQuoteSafe(tokenIn);

            uint256 amountEBTCRaw = (amountTokenToDeposit * ONE_SHARE) / rate;
            IVedaTeller.Asset memory data = IVedaTeller(vedaTeller).assetData(tokenIn);

            amountTokenToDeposit = (amountEBTCRaw * (PREMIUM_SHARE_BPS - data.sharePremium)) / PREMIUM_SHARE_BPS;
            tokenIn = eBTC;
        }
        return super._previewDeposit(tokenIn, amountTokenToDeposit);
    }

    function isValidTokenIn(address token) public view override returns (bool) {
        return token == eBTC || token == wBTC || token == cbBTC || token == LBTC || token == aToken;
    }

    function getTokensIn() public view override returns (address[] memory res) {
        return ArrayLib.create(wBTC, cbBTC, eBTC, LBTC, aToken);
    }

    function assetInfo()
        external
        view
        virtual
        override
        returns (AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (AssetType.TOKEN, eBTC, IERC20Metadata(eBTC).decimals());
    }

    function getAbsoluteSupplyCap() external view returns (uint256) {
        uint256 data = (IZerolendPool(ZEROLEND_POOL).getConfiguration(eBTC)).data;
        uint256 unscaledSupplyCap = (data &
            (~uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF))) >> 116;
        return unscaledSupplyCap * (10 ** IERC20Metadata(eBTC).decimals());
    }

    function getAbsoluteTotalSupply() external view returns (uint256) {
        return IZerolendZ0Token(Z0EBTC).scaledTotalSupply();
    }
}
