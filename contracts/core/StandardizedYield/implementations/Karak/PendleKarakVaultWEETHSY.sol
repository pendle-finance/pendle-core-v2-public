// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendleKarakVaultSYBaseUpg.sol";
import "../../../../interfaces/EtherFi/IEtherFiLiquidityPool.sol";
import "../../../../interfaces/EtherFi/IEtherFiWEEth.sol";

contract PendleKarakVaultWEETHSY is PendleKarakVaultSYBaseUpg {
    // solhint-disable immutable-vars-naming
    address public immutable weETH;
    address public immutable liquidityPool;
    address public immutable eETH;
    address public immutable referee;

    constructor(
        address _vault,
        address _vaultSupervisor,
        address _referee
    ) PendleKarakVaultSYBaseUpg(_vault, _vaultSupervisor) {
        weETH = IERC4626(_vault).asset();
        liquidityPool = IEtherFiWEEth(weETH).liquidityPool();
        eETH = IEtherFiWEEth(weETH).eETH();
        referee = _referee;

        _disableInitializers();
    }

    function initialize() external initializer {
        __SYBaseUpg_init("SY Karak WEETH", "SY-Karak-WEETH");
        __KarakVaultSY_init();
        _safeApproveInf(eETH, weETH);
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function _getStakeTokenExchangeRate() internal view virtual override returns (uint256) {
        return IEtherFiLiquidityPool(liquidityPool).amountForShare(1 ether);
    }

    /*///////////////////////////////////////////////////////////////
                    ADDITIONAL TOKEN IN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getAdditionalTokens() internal view virtual override returns (address[] memory) {
        return ArrayLib.create(eETH, NATIVE);
    }

    function _previewToStakeToken(
        address,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256) {
        return IEtherFiLiquidityPool(liquidityPool).sharesForAmount(amountTokenToDeposit);
    }

    function _wrapToStakeToken(address tokenIn, uint256 amountDeposited) internal virtual override returns (uint256) {
        if (tokenIn == NATIVE) {
            IEtherFiLiquidityPool(liquidityPool).deposit{value: amountDeposited}(referee);
        }
        return IEtherFiWEEth(weETH).wrap(_selfBalance(eETH));
    }

    function _canWrapToStakeToken(address tokenIn) internal view virtual override returns (bool) {
        return tokenIn == eETH || tokenIn == NATIVE;
    }

    function assetInfo() external view override returns (AssetType, address, uint8) {
        return (AssetType.TOKEN, eETH, 18);
    }
}
