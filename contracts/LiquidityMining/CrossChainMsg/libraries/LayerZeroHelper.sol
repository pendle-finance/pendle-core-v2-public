// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library LayerZeroHelper {
    uint256 constant EVM_ADDRESS_SIZE = 20;

    function _getLayerZeroChainIds(uint256 chainId) internal pure returns (uint16) {
        // fuji testnet
        if (chainId == 43_113) return 10_106;
        // mumbai testnet
        else if (chainId == 80_001) return 10_109;
        // avax mainnet
        else if (chainId == 43_114) return 106;
        // arbitrum one
        else if (chainId == 42_161) return 110;
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
        // sonic
        else if (chainId == 146) return 332;
        // bera
        else if (chainId == 80_094) return 362;
        // hyperevm
        else if (chainId == 999) return 367;
        // plasma
        else if (chainId == 9745) return 383;
        assert(false);
    }

    function _getOriginalChainIds(uint16 chainId) internal pure returns (uint256) {
        // fuji testnet
        if (chainId == 10_106) return 43_113;
        // mumbai testnet
        else if (chainId == 10_109) return 80_001;
        // avax mainnet
        else if (chainId == 106) return 43_114;
        // arbitrum one
        else if (chainId == 110) return 42_161;
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
        // sonic
        else if (chainId == 332) return 146;
        // bera
        else if (chainId == 362) return 80_094;
        // hyperevm
        else if (chainId == 367) return 999;
        // plasma
        else if (chainId == 383) return 9745;
        assert(false);
    }

    function _getFirstAddressFromPath(bytes memory path) internal pure returns (address dst) {
        assembly {
            dst := mload(add(add(path, EVM_ADDRESS_SIZE), 0))
        }
    }
}
