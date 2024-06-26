// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../SYBaseUpg.sol";
import "../../StEthHelper.sol";
import "../../../../interfaces/IPTokenWithSupplyCap.sol";
import "../../../../interfaces/Mellow/IMellowVault.sol";
import "../../../../interfaces/Mellow/IMellowVaultConfigurator.sol";
import "../../../../interfaces/IPPriceFeed.sol";

/// @dev This SY implementation intends to ignore native interest from Mellow Vault's underlying
contract PendleMellowVaultSYBaseUpg is SYBaseUpg, IPTokenWithSupplyCap {
    event SetPricingHelper(address newPricingHelper);

    // solhint-disable immutable-vars-naming
    address public immutable vault;
    address public immutable configurator;
    address public pricingHelper;

    constructor(address _vault) SYBaseUpg(_vault) {
        vault = _vault;
        configurator = IMellowVault(_vault).configurator();
        _disableInitializers();
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        address _pricingHelper
    ) external virtual initializer {
        __SYBaseUpg_init(_name, _symbol);
        _setPricingHelper(_pricingHelper);
    }

    function _deposit(
        address /*tokenIn*/,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 amountSharesOut) {
        return amountDeposited;
    }

    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256) {
        _transferOut(vault, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
    }

    function exchangeRate() public view virtual override returns (uint256 res) {
        return PMath.ONE;
    }

    function _previewDeposit(
        address /*tokenIn*/,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 /*amountSharesOut*/) {
        return amountTokenToDeposit;
    }

    function _previewRedeem(
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal view virtual override returns (uint256 /*amountTokenOut*/) {
        return amountSharesToRedeem;
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        return ArrayLib.create(vault);
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        return ArrayLib.create(vault);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == vault;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == vault;
    }

    function assetInfo()
        external
        view
        virtual
        returns (AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (AssetType.TOKEN, vault, IERC20Metadata(vault).decimals());
    }

    function getAbsoluteSupplyCap() external view virtual returns (uint256) {
        return IMellowVaultConfigurator(configurator).maximalTotalSupply();
    }

    function getAbsoluteTotalSupply() external view virtual returns (uint256) {
        return IERC20(vault).totalSupply();
    }

    /*///////////////////////////////////////////////////////////////
                        OFF-CHAIN USAGE ONLY
            (NO SECURITY RELATED && CAN BE LEFT UNAUDITED)
    //////////////////////////////////////////////////////////////*/

    function setPricingHelper(address _pricingHelper) external onlyOwner {
        _setPricingHelper(_pricingHelper);
    }

    function _setPricingHelper(address _pricingHelper) internal {
        pricingHelper = _pricingHelper;
        emit SetPricingHelper(_pricingHelper);
    }

    function getPrice() external view returns (uint256) {
        return IPPriceFeed(pricingHelper).getPrice();
    }
}
