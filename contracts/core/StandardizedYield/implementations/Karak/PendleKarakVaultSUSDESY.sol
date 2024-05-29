// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../../../interfaces/IPTokenWithSupplyCap.sol";
import "./PendleKarakVaultSYBaseUpg.sol";

contract PendleKarakVaultSUSDESY is PendleKarakVaultSYBaseUpg, IPTokenWithSupplyCap {
    // solhint-disable immutable-vars-naming
    address public immutable usde;
    address public immutable susde;

    constructor(address _vault, address _vaultSupervisor) PendleKarakVaultSYBaseUpg(_vault, _vaultSupervisor) {
        susde = IERC4626(_vault).asset();
        usde = IERC4626(susde).asset();
    }

    function getAbsoluteSupplyCap() external view returns (uint256) {
        uint256 assetLimit = IKarakVault(vault).assetLimit();
        return IERC4626(vault).convertToShares(assetLimit);
    }

    function getAbsoluteTotalSupply() external view returns (uint256) {
        return IERC20(vault).totalSupply();
    }

    function initialize() external initializer {
        __SYBaseUpg_init("SY Karak sUSDe", "SY-Karak-sUSDe");
        __KarakVaultSY_init();
        _safeApproveInf(usde, susde);
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function _getStakeTokenExchangeRate() internal view virtual override returns (uint256) {
        return IERC4626(susde).previewRedeem(PMath.ONE);
    }

    /*///////////////////////////////////////////////////////////////
                    ADDITIONAL TOKEN IN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getAdditionalTokens() internal view virtual override returns (address[] memory) {
        return ArrayLib.create(usde);
    }

    function _previewToStakeToken(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256) {
        assert(tokenIn == usde);

        return IERC4626(susde).previewDeposit(amountTokenToDeposit);
    }

    function _wrapToStakeToken(address tokenIn, uint256 amountDeposited) internal virtual override returns (uint256) {
        assert(tokenIn == usde);

        return IERC4626(susde).deposit(amountDeposited, address(this));
    }

    function _canWrapToStakeToken(address tokenIn) internal view virtual override returns (bool) {
        return tokenIn == usde;
    }

    function assetInfo() external view override returns (AssetType, address, uint8) {
        return (AssetType.TOKEN, usde, 18);
    }
}
