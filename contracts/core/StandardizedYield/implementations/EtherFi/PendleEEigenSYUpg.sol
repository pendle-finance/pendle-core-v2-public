// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "../PendleERC20SYUpg.sol";
import "../../../../interfaces/EtherFi/IVedaTeller.sol";
import "../../../../interfaces/EtherFi/IVedaAccountant.sol";

contract PendleEEigenSYUpg is PendleERC20SYUpg {
    using PMath for uint256;

    // solhint-disable immutable-vars-naming
    // solhint-disable const-name-snakecase
    address public constant EIGEN = 0xec53bF9167f50cDEB3Ae105f56099aaaB9061F83;
    address public constant EEIGEN = 0xE77076518A813616315EaAba6cA8e595E845EeE9;
    address public constant vedaTeller = 0x63b2B0528376d1B34Ed8c9FF61Bd67ab2C8c2Bb0;

    address public immutable vedaAccountant;

    constructor() PendleERC20SYUpg(EEIGEN) {
        vedaAccountant = IVedaTeller(vedaTeller).accountant();
    }

    function initialize() external initializer {
        __SYBaseUpg_init("SY ether.fi EIGEN", "SY-eEIGEN");
        _safeApproveInf(EIGEN, EEIGEN);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == EEIGEN) {
            return amountDeposited;
        }
        return IVedaTeller(vedaTeller).bulkDeposit(tokenIn, amountDeposited, 0, address(this));
    }

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == EEIGEN) {
            return amountTokenToDeposit;
        }
        uint256 rate = IVedaAccountant(vedaAccountant).getRateInQuoteSafe(tokenIn);
        amountSharesOut = amountTokenToDeposit.divDown(rate);
    }

    function isValidTokenIn(address token) public pure override returns (bool) {
        return token == EIGEN || token == EEIGEN;
    }

    function getTokensIn() public pure override returns (address[] memory res) {
        return ArrayLib.create(EIGEN, EEIGEN);
    }

    /// =================================================================

    function exchangeRate() public view virtual override returns (uint256) {
        return IVedaAccountant(vedaAccountant).getRateInQuoteSafe(EIGEN);
    }

    function assetInfo()
        external
        view
        override
        returns (AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (AssetType.TOKEN, EIGEN, IERC20Metadata(EIGEN).decimals());
    }
}
