// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../interfaces/IPAllAction.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPRouterHelper.sol";
import "./base/ActionBaseMintRedeem.sol";
import "./base/MarketApproxLib.sol";
import "../interfaces/IAddressProvider.sol";

contract PendleRouterHelper2 is TokenHelper {
    IPAllAction public immutable ROUTER;
    address public immutable WETH;

    constructor(address _ROUTER, address _WETH) {
        ROUTER = IPAllAction(_ROUTER);
        WETH = _WETH;
        _safeApproveInf(WETH, address(ROUTER));
    }

    receive() external payable {}

    /**
     * @dev all the parameters for this function should be generated in the same way as they are
     *  generated for the main Router, except that input.tokenIn & swapData should be generated
     *  for tokenIn == WETH instead of ETH
     */
    function mintSyFromToken(
        address receiver,
        address SY,
        uint256 minSyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netSyOut) {
        require(input.tokenIn == WETH);

        _transferIn(NATIVE, msg.sender, input.netTokenIn);

        _wrap_unwrap_ETH(NATIVE, WETH, input.netTokenIn);
        netSyOut = ROUTER.mintSyFromToken(receiver, SY, minSyOut, input);
    }
}
