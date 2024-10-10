// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;
import "../PendleERC4626NotRedeemableToAssetSY.sol";
import "../../../../interfaces/Syrup/ISyrupRouter.sol";

contract PendleSyrupSY is PendleERC4626NotRedeemableToAssetSY {
    // solhint-disable immutable-vars-naming
    address public immutable syrupRouter;
    bytes32 public constant PENDLE_DEPOSIT_DATA = 0x303a70656e646c65000000000000000000000000000000000000000000000000;

    constructor(
        string memory _name,
        string memory _symbol,
        address _syrupRouter
    ) PendleERC4626NotRedeemableToAssetSY(_name, _symbol, ISyrupRouter(_syrupRouter).pool()) {
        syrupRouter = _syrupRouter;
        _safeApproveInf(asset, syrupRouter);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == yieldToken) {
            return amountDeposited;
        } else {
            return ISyrupRouter(syrupRouter).deposit(amountDeposited, PENDLE_DEPOSIT_DATA);
        }
    }
}
