// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendleKarakVaultSYBaseUpg.sol";
import "../../../../interfaces/IPExchangeRateOracle.sol";
import "../../../../interfaces/Renzo/IRenzoRestakeManager.sol";
import "../../../../interfaces/Renzo/IRenzoOracle.sol";

contract PendleKarakVaultEzETHSY is PendleKarakVaultSYBaseUpg {
    // solhint-disable immutable-vars-naming
    address public immutable ezETH;
    address public immutable restakeManager;
    address public immutable renzoOracle;
    uint256 public immutable referralId;
    address public immutable exchangeRateOracle;

    constructor(
        address _vault,
        address _vaultSupervisor,
        address _ezETH,
        address _restakeManager,
        uint256 _referralId,
        address _exchangeRateOracle
    ) PendleKarakVaultSYBaseUpg(_vault, _vaultSupervisor) {
        ezETH = _ezETH;
        restakeManager = _restakeManager;
        renzoOracle = IRenzoRestakeManager(restakeManager).renzoOracle();
        referralId = _referralId;
        exchangeRateOracle = _exchangeRateOracle;

        _disableInitializers();
    }

    function initialize() external initializer {
        __SYBaseUpg_init("SY Karak ezETH", "SY-Karak-ezETH");
        __KarakVaultSY_init();
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function _getStakeTokenExchangeRate() internal view virtual override returns (uint256) {
        return IPExchangeRateOracle(exchangeRateOracle).getExchangeRate();
    }

    /*///////////////////////////////////////////////////////////////
                    ADDITIONAL TOKEN IN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getAdditionalTokens() internal view virtual override returns (address[] memory) {
        return ArrayLib.create(NATIVE);
    }

    function _previewToStakeToken(
        address /*tokenIn*/,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256) {
        uint256 supply = IERC20(ezETH).totalSupply();
        (, , uint256 tvl) = IRenzoRestakeManager(restakeManager).calculateTVLs();
        return IRenzoOracle(renzoOracle).calculateMintAmount(tvl, amountTokenToDeposit, supply);
    }

    function _wrapToStakeToken(
        address /*tokenIn*/,
        uint256 amountDeposited
    ) internal virtual override returns (uint256) {
        uint256 preBalance = _selfBalance(ezETH);
        IRenzoRestakeManager(restakeManager).depositETH{value: amountDeposited}(referralId);
        return _selfBalance(ezETH) - preBalance;
    }

    function _canWrapToStakeToken(address tokenIn) internal view virtual override returns (bool) {
        return tokenIn == NATIVE;
    }

    function assetInfo() external pure override returns (AssetType, address, uint8) {
        return (AssetType.TOKEN, NATIVE, 18);
    }
}
