// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../SYBase.sol";
import "../../StEthHelper.sol";
import "../../../../interfaces/IERC4626.sol";

contract PendleAmphorWstETHVaultSY is SYBase, StEthHelper {
    address public constant VAULT = 0x06824C27C8a0DbDe5F72f770eC82e3c0FD4DcEc3;

    constructor() SYBase("SY Amphor LRT", "SY-amphrLRT", VAULT) {
        _safeApproveInf(WSTETH, VAULT);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == NATIVE) {
            (amountDeposited, tokenIn) = (_depositWstETH(NATIVE, amountDeposited), WSTETH);
        }
        if (tokenIn == WSTETH) {
            return IERC4626(VAULT).deposit(amountDeposited, address(this));
        }
        return amountDeposited;
    }

    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal override returns (uint256) {
        _transferOut(VAULT, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
    }

    function exchangeRate() public view virtual override returns (uint256) {
        return PMath.ONE;
    }

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == NATIVE) {
            return _previewDepositWstETH(NATIVE, amountTokenToDeposit);
        }
        return amountTokenToDeposit;
    }

    function _previewRedeem(
        address,
        uint256 amountSharesToRedeem
    ) internal pure override returns (uint256 /*amountTokenOut*/) {
        return amountSharesToRedeem;
    }

    function getTokensIn() public pure override returns (address[] memory res) {
        return ArrayLib.create(NATIVE, WSTETH, VAULT);
    }

    function getTokensOut() public pure override returns (address[] memory res) {
        return ArrayLib.create(VAULT);
    }

    function isValidTokenIn(address token) public pure override returns (bool) {
        return token == NATIVE || token == WSTETH || token == VAULT;
    }

    function isValidTokenOut(address token) public pure override returns (bool) {
        return token == VAULT;
    }

    function assetInfo() external pure returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, VAULT, 18);
    }
}
