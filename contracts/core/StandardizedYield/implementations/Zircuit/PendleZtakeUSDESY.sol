// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../SYBaseUpg.sol";
import "../../../../interfaces/Zircuit/IZircuitZtaking.sol";

contract PendleZtakeUSDESY is SYBaseUpg {
    // solhint-disable immutable-vars-naming
    address public immutable zircuitStaking;
    address public immutable usde;

    // Supply cap might be updated more often than on special occasion. Leave it as normal storage for better conveinence.
    uint256 public supplyCap;

    event SupplyCapUpdated(uint256 newSupplyCap);

    error SupplyCapExceeded(uint256 totalSupply, uint256 supplyCap);

    constructor(address _zircuitStaking, address _usde) SYBaseUpg(_usde) {
        _disableInitializers();
        zircuitStaking = _zircuitStaking;
        usde = _usde;
    }

    function initialize(uint256 _initialSupplyCap) external initializer {
        __SYBaseUpg_init("SY Zircuit Staking USDe", "SY-zs-USDe");
        _safeApproveInf(usde, zircuitStaking);
        _updateSupplyCap(_initialSupplyCap);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address /*tokenIn*/, uint256 amountDeposited) internal virtual override returns (uint256) {
        IZircuitZtaking(zircuitStaking).depositFor(usde, address(this), amountDeposited);
        return amountDeposited;
    }

    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal override returns (uint256 /*amountTokenOut*/) {
        IZircuitZtaking(zircuitStaking).withdraw(usde, amountSharesToRedeem);
        _transferOut(usde, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return PMath.ONE;
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address /*tokenIn*/,
        uint256 amountTokenToDeposit
    ) internal view override returns (uint256 /*amountSharesOut*/) {
        uint256 _newSupply = totalSupply() + amountTokenToDeposit;
        uint256 _supplyCap = supplyCap;

        if (_newSupply > _supplyCap) {
            revert SupplyCapExceeded(_newSupply, _supplyCap);
        }

        return amountTokenToDeposit;
    }

    function _previewRedeem(
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal pure override returns (uint256 /*amountTokenOut*/) {
        return amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                SUPPLY CAP RELATED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function updateSupplyCap(uint256 newSupplyCap) external onlyOwner {
        _updateSupplyCap(newSupplyCap);
    }

    function _updateSupplyCap(uint256 newSupplyCap) internal {
        supplyCap = newSupplyCap;
        emit SupplyCapUpdated(newSupplyCap);
    }

    // @dev: whenNotPaused not needed as it has already been added to beforeTransfer
    function _afterTokenTransfer(address from, address, uint256) internal virtual override {
        // only check for minting case
        // saving gas on user->user transfers
        // skip supply cap checking on burn to allow lowering supply cap
        if (from != address(0)) {
            return;
        }

        uint256 _supply = totalSupply();
        uint256 _supplyCap = supplyCap;
        if (_supply > _supplyCap) {
            revert SupplyCapExceeded(_supply, _supplyCap);
        }
    }

    function getTokensIn() public view override returns (address[] memory res) {
        return ArrayLib.create(usde);
    }

    function getTokensOut() public view override returns (address[] memory res) {
        return ArrayLib.create(usde);
    }

    function isValidTokenIn(address token) public view override returns (bool) {
        return token == usde;
    }

    function isValidTokenOut(address token) public view override returns (bool) {
        return token == usde;
    }

    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        assetType = AssetType.TOKEN;
        assetAddress = usde;
        assetDecimals = IERC20Metadata(usde).decimals();
    }
}
