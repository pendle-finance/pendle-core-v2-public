// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {IPriceOracleGetter, IERC20} from "./IPriceOracleGetter.sol";
import {IPoolAddressesProvider} from "./IPoolAddressesProvider.sol";

interface IAaveOracle is IPriceOracleGetter {
    /**
     * @notice Returns the PoolAddressesProvider
     * @return The address of the PoolAddressesProvider contract
     */
    function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

    /**
     * @notice Returns a list of prices from a list of assets addresses
     * @param assets The list of assets addresses
     * @return The prices of the given assets
     */
    function getAssetsPrices(IERC20[] calldata assets) external view returns (uint256[] memory);

    /**
     * @notice Returns the address of the source for an asset address
     * @param asset The address of the asset
     * @return The address of the source
     */
    function getSourceOfAsset(IERC20 asset) external view returns (address);

    /**
     * @notice Returns the address of the fallback oracle
     * @return The address of the fallback oracle
     */
    function getFallbackOracle() external view returns (address);
}
