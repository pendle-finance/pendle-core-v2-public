// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendleKarakVaultSYBaseUpg.sol";
import "../../../../interfaces/EtherFi/IEtherFiLiquidityPool.sol";
import "../../../../interfaces/EtherFi/IEtherFiWEEth.sol";

contract PendleKarakVaultERC20SY is PendleKarakVaultSYBaseUpg {
    // solhint-disable immutable-vars-naming
    // solhint-disable no-empty-blocks

    constructor(address _vault, address _vaultSupervisor) PendleKarakVaultSYBaseUpg(_vault, _vaultSupervisor) {
        _disableInitializers();
    }

    function initialize(string memory _name, string memory _symbol) external initializer {
        __SYBaseUpg_init(_name, _symbol);
        __KarakVaultSY_init();
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function _getStakeTokenExchangeRate() internal view virtual override returns (uint256) {
        return PMath.ONE;
    }

    function assetInfo() external view override returns (AssetType, address, uint8) {
        return (AssetType.TOKEN, stakeToken, IERC20Metadata(stakeToken).decimals());
    }
}
