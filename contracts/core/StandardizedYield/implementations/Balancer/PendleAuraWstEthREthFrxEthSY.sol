// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../../../interfaces/Balancer/IBasePool.sol";
import "./base/PendleBalancerCommonPoolSY.sol";
import "./base/StableMath.sol";

contract PendleAuraWstEthREthFrxEthSY is PendleBalancerCommonPoolSY {
    uint256 constant PID = 13;
    address constant POOL = 0x8e85e97ed19C0fa13B2549309965291fbbc0048b;

    constructor(
        string memory _name,
        string memory _symbol
    ) PendleBalancerCommonPoolSY(_name, _symbol, POOL, PID) {}

    function getTokensIn() public view virtual override returns (address[] memory res) {
        return _getPoolTokens();
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        return _getPoolTokens();
    }

    function _previewDepositToBalancerSingleToken(
        address token,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 amountLpOut) {
        // TODO
        return 0;
    }

    function _previewRedeemFromBalancerSingleToken(
        address token,
        uint256 amountLpToRedeem
    ) internal view virtual override returns (uint256 amountTokenOut) {
        // TODO
        return 0;
    }
}
