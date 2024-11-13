// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library LayerZeroHelper {
    uint256 constant EVM_ADDRESS_SIZE = 20;

    function _getLayerZeroChainIds(uint256 chainId) internal pure returns (uint16) {
        // fuji testnet
        if (chainId == 43113) return 10106;
        // mumbai testnet
        else if (chainId == 80001) return 10109;
        // avax mainnet
        else if (chainId == 43114) return 106;
        // arbitrum one
        else if (chainId == 42161) return 110;
        // binance smart chain
        else if (chainId == 56) return 102;
        // mainnet
        else if (chainId == 1) return 101;
        // mantle
        else if (chainId == 5000) return 181;
        // optimism
        else if (chainId == 10) return 111;
        // base
        else if (chainId == 8453) return 184;
        assert(false);
    }

    function _getOriginalChainIds(uint16 chainId) internal pure returns (uint256) {
        // fuji testnet
        if (chainId == 10106) return 43113;
        // mumbai testnet
        else if (chainId == 10109) return 80001;
        // avax mainnet
        else if (chainId == 106) return 43114;
        // arbitrum one
        else if (chainId == 110) return 42161;
        // binance smart chain
        else if (chainId == 102) return 56;
        // mainnet
        else if (chainId == 101) return 1;
        // mantle
        else if (chainId == 181) return 5000;
        // optimism
        else if (chainId == 111) return 10;
        // base
        else if (chainId == 184) return 8453;
        assert(false);
    }

    function _getFirstAddressFromPath(bytes memory path) internal pure returns (address dst) {
        assembly {
            dst := mload(add(add(path, EVM_ADDRESS_SIZE), 0))
        }
    }
}
