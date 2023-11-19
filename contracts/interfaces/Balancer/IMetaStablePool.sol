// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IBasePool.sol";

interface IMetaStablePool is IBasePool {
    function getLastInvariant() external view returns (uint256 lastInvariant, uint256 lastInvariantAmp);

    function getAmplificationParameter() external view returns (uint256 value, bool isUpdating, uint256 precision);

    function getSwapFeePercentage() external view returns (uint256);

    function getPriceRateCache(IERC20 token) external view returns (uint256 rate, uint256 duration, uint256 expires);
}
