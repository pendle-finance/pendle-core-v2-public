// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../../../interfaces/Solv/ISolvRouter.sol";

library PendleSolvHelper {
    address public constant SOLV_BTCBBN_ROUTER = 0x01024AaeD5561fa6237C0ad4073417576C591261;
    address public constant SOLV_BTCBBN_TOKEN = 0xd9D920AA40f578ab794426F5C90F6C731D159DEf;
    bytes32 public constant SOLV_BTCBBN_POOLID = 0xefcca1eb946cdc7b56509489a56b45b75aff74b8bb84dad5b893012157e0df93;


    address public constant SOLV_BTC_ROUTER = 0x1fF7d7C0A7D8E94046708C611DeC5056A9d2B823;
    address public constant SOLV_BTC_TOKEN = 0x7A56E1C57C7475CCf742a1832B028F0456652F97;
    bytes32 public constant SOLV_BTC_POOLID = 0x716db7dc196abe78d5349c7166896f674ab978af26ada3e5b3ea74c5a1b48307;

    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    function _mintBTCBBN(address tokenIn, uint256 amountIn) internal returns (uint256) {
        if (tokenIn == WBTC) {
            amountIn = ISolvRouter(SOLV_BTC_ROUTER).createSubscription(SOLV_BTC_POOLID, amountIn);
        }
        return ISolvRouter(SOLV_BTCBBN_ROUTER).createSubscription(SOLV_BTCBBN_POOLID, amountIn);
    }
}