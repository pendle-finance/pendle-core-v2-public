// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;
import "../PendleERC4626NotRedeemableToAssetSY.sol";
import "../../../../interfaces/Syrup/ISyrupRouter.sol";

contract PendleSyrupSY is PendleERC4626NotRedeemableToAssetSY {
    using PMath for uint256;

    // solhint-disable immutable-vars-naming
    address public immutable syrupToken;
    address public immutable syrupRouter;

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
            return ISyrupRouter(syrupRouter).deposit(amountDeposited, bytes32(0));
        }
    }
}
