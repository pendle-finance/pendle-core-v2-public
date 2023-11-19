// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IBasePool.sol";
import "./IRateProvider.sol";

interface IComposableStable is IBasePool {
    function getLastJoinExitData()
        external
        view
        returns (uint256 lastJoinExitAmplification, uint256 lastPostJoinExitInvariant);

    function getAmplificationParameter() external view returns (uint256 value, bool isUpdating, uint256 precision);

    function getProtocolFeePercentageCache(uint256 feeType) external view returns (uint256);

    function isTokenExemptFromYieldProtocolFee(IERC20 token) external view returns (bool);

    function getTokenRateCache(
        IERC20 token
    ) external view returns (uint256 rate, uint256 oldRate, uint256 duration, uint256 expires);

    function getRateProviders() external view returns (IRateProvider[] memory);

    function getBptIndex() external view returns (uint256);

    function getTokenRate(IERC20 token) external view returns (uint256);
}
