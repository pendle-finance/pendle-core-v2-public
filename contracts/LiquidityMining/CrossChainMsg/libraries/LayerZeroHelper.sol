// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

library LayerZeroHelper {
    uint256 constant EVM_ADDRESS_SIZE = 20;

    function _getLayerZeroChainIds(uint256 chainId) internal pure returns (uint16) {
        if (chainId == 43113) return 10106;
        // fuji testnet
        else if (chainId == 80001) return 10109;
        // mumbai testnet
        else if (chainId == 43114) return 106; // avax mainnet
        assert(false);
    }

    function _getOriginalChainIds(uint16 chainId) internal pure returns (uint256) {
        if (chainId == 10106) return 43113;
        // fuji testnet
        else if (chainId == 10109) return 80001;
        // mumbai testnet
        else if (chainId == 106) return 43114; // avax mainnet
        assert(false);
    }

    function _getFirstAddressFromPath(bytes memory path) internal pure returns (address dst) {
        assembly {
            dst := mload(add(add(path, EVM_ADDRESS_SIZE), 0))
        }
    }
}
