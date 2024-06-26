// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./PendleMellowVaultSYBaseUpg.sol";

/// @dev This SY implementation intends to ignore native interest from Mellow Vault's underlying
contract PendleMellowVaultWstETHSYUpg is PendleMellowVaultSYBaseUpg, StEthHelper {
    error MellowVaultHasInvalidAssets();
    error SupplyCapExceeded(uint256 totalSupply, uint256 supplyCap);

    // solhint-disable immutable-vars-naming
    uint256 public immutable interfaceVersion;

    constructor(address _vault, uint256 _interfaceVersion) PendleMellowVaultSYBaseUpg(_vault) {
        if (_interfaceVersion > 1) {
            revert("invalid interface version");
        }
        interfaceVersion = _interfaceVersion;
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        address _pricingHelper
    ) external override initializer {
        __SYBaseUpg_init(_name, _symbol);
        _safeApproveInf(STETH, WSTETH);
        _safeApproveInf(WSTETH, vault);
        _setPricingHelper(_pricingHelper);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == vault) {
            return amountDeposited;
        }
        if (tokenIn != WSTETH) {
            (tokenIn, amountDeposited) = (WSTETH, _depositWstETH(tokenIn, amountDeposited));
        }

        if (interfaceVersion == 0) {
            (, amountSharesOut) = IMellowVault(vault).deposit(
                address(this),
                ArrayLib.create(amountDeposited),
                0,
                type(uint256).max,
                0
            );
        } else if (interfaceVersion == 1) {
            (, amountSharesOut) = IMellowVault(vault).deposit(
                address(this),
                ArrayLib.create(amountDeposited),
                0,
                type(uint256).max
            );
        }
    }

    /// @dev Mellow uses math calculations under 2**96 base. Also they are taking into account oracle prices
    /// even with one asset. So a discrepancy of 1e-6 in the result should be expected.
    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == vault) {
            return amountTokenToDeposit;
        }
        if (tokenIn != WSTETH) {
            (tokenIn, amountTokenToDeposit) = (WSTETH, _previewDepositWstETH(tokenIn, amountTokenToDeposit));
        }
        (uint256 tvl, uint256 supply) = _getMellowVaultTvl();
        amountSharesOut = (amountTokenToDeposit * supply) / tvl;

        uint256 supplyCap = IMellowVaultConfigurator(configurator).maximalTotalSupply();
        uint256 newSupply = supply + amountSharesOut;
        if (newSupply > supplyCap) {
            revert SupplyCapExceeded(newSupply, supplyCap);
        }
    }

    function getTokensIn() public view override returns (address[] memory res) {
        return ArrayLib.create(NATIVE, STETH, WSTETH, vault);
    }

    function isValidTokenIn(address token) public view override returns (bool) {
        return token == NATIVE || token == STETH || token == WSTETH || token == vault;
    }

    /// @dev returns mellow TVL in WSTETH
    /// @dev reverts if the vault contains more than 1 token
    function _getMellowVaultTvl() internal view returns (uint256 tvl, uint256 supply) {
        (address[] memory tokens, uint256[] memory amounts) = IMellowVault(vault).underlyingTvl();
        if (tokens.length > 1 || tokens[0] != WSTETH) {
            revert MellowVaultHasInvalidAssets();
        }

        tvl = amounts[0];
        supply = IERC20(vault).totalSupply();
    }
}
