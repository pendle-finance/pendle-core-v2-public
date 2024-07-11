// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./PendleMellowVaultSYBaseUpg.sol";
import "../../../../interfaces/IERC4626.sol";

contract PendleMellowVaultERC4626SYUpg is PendleMellowVaultSYBaseUpg {
    error MellowVaultHasInvalidAssets();
    error SupplyCapExceeded(uint256 totalSupply, uint256 supplyCap);

    using PMath for uint256;

    // solhint-disable immutable-vars-naming
    address public immutable erc4626;
    address public immutable asset;

    // solhint-disable immutable-vars-naming
    uint256 public immutable interfaceVersion;

    constructor(address _erc4626, address _vault, uint256 _interfaceVersion) PendleMellowVaultSYBaseUpg(_vault) {
        erc4626 = _erc4626;
        asset = IERC4626(_erc4626).asset();

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
        _safeApproveInf(asset, erc4626);
        _safeApproveInf(erc4626, vault);
        _setPricingHelper(_pricingHelper);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == vault) {
            return amountDeposited;
        }
        if (tokenIn != erc4626) {
            (tokenIn, amountDeposited) = (erc4626, IERC4626(erc4626).deposit(amountDeposited, address(this)));
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

    function exchangeRate() public view virtual override returns (uint256 res) {
        (uint256 tvl, uint256 supply) = _getMellowVaultTvl();
        return IERC4626(erc4626).convertToAssets((tvl * PMath.ONE) / supply);
    }

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == vault) {
            return amountTokenToDeposit;
        }

        if (tokenIn != erc4626) {
            (tokenIn, amountTokenToDeposit) = (erc4626, IERC4626(erc4626).previewDeposit(amountTokenToDeposit));
        }

        (uint256 tvl, uint256 supply) = _getMellowVaultTvl();
        amountSharesOut = (amountTokenToDeposit * supply) / tvl;

        uint256 supplyCap = IMellowVaultConfigurator(configurator).maximalTotalSupply();
        uint256 newSupply = supply + amountSharesOut;
        if (newSupply > supplyCap) {
            revert SupplyCapExceeded(newSupply, supplyCap);
        }
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        return ArrayLib.create(asset, erc4626, vault);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == asset || token == erc4626 || token == vault;
    }

    /// @dev returns mellow TVL in erc4626
    /// @dev reverts if the vault contains more than 1 token
    function _getMellowVaultTvl() internal view returns (uint256 tvl, uint256 supply) {
        (address[] memory tokens, uint256[] memory amounts) = IMellowVault(vault).underlyingTvl();
        if (tokens.length > 1 || tokens[0] != erc4626) {
            revert MellowVaultHasInvalidAssets();
        }

        tvl = amounts[0];
        supply = IERC20(vault).totalSupply();
    }

    function assetInfo()
        external
        view
        virtual
        override
        returns (AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (AssetType.TOKEN, asset, IERC20Metadata(asset).decimals());
    }
}
