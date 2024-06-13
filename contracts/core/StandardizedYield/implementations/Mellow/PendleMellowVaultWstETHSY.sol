// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./PendleMellowVaultERC20SY.sol";

/// @dev This SY implementation intends to ignore native interest from Mellow Vault's underlying
contract PendleMellowVaultWstETHSY is PendleMellowVaultERC20SY, StEthHelper {
    error MellowVaultHasInvalidAssets();

    constructor(
        string memory _name,
        string memory _symbol,
        address _vault
    ) PendleMellowVaultERC20SY(_name, _symbol, _vault) {}

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
        (, amountSharesOut) = IMellowVault(vault).deposit(
            address(this),
            ArrayLib.create(amountDeposited),
            0,
            type(uint256).max,
            0
        );
    }

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == vault) {
            return amountTokenToDeposit;
        }
        if (tokenIn != WSTETH) {
            (tokenIn, amountTokenToDeposit) = (WSTETH, _previewDepositWstETH(tokenIn, amountTokenToDeposit));
        }
        (uint256 tvl, uint256 supply) = _getMellowVaultTvl();
        return (amountTokenToDeposit * supply) / tvl;
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
