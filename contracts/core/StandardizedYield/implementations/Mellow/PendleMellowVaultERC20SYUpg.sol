// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendleMellowVaultSYBaseUpg.sol";

contract PendleMellowVaultERC20SYUpg is PendleMellowVaultSYBaseUpg {
    error MellowVaultHasInvalidAssets();
    error SupplyCapExceeded(uint256 totalSupply, uint256 supplyCap);

    using PMath for uint256;

    // solhint-disable immutable-vars-naming
    address public immutable depositToken;

    // solhint-disable immutable-vars-naming
    uint256 public immutable interfaceVersion;

    // [ERC20 deposit of the vault, vault address, interface version (0 = referral, 1 = non referral)]
    constructor(address _depositToken, address _vault, uint256 _interfaceVersion) PendleMellowVaultSYBaseUpg(_vault) {
        depositToken = _depositToken;
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
        _safeApproveInf(depositToken, vault);
        _setPricingHelper(_pricingHelper);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == vault) {
            return amountDeposited;
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
        return (tvl * PMath.ONE) / supply;
    }

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == vault) {
            return amountTokenToDeposit;
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
        return ArrayLib.create(depositToken, vault);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == depositToken || token == vault;
    }

    /// @dev returns mellow TVL in depositToken
    /// @dev reverts if the vault contains more than 1 token
    function _getMellowVaultTvl() internal view returns (uint256 tvl, uint256 supply) {
        (address[] memory tokens, uint256[] memory amounts) = IMellowVault(vault).underlyingTvl();
        if (tokens.length > 1 || tokens[0] != depositToken) {
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
        return (AssetType.TOKEN, depositToken, IERC20Metadata(depositToken).decimals());
    }
}
