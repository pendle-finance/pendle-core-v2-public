// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBasePool {
    function getPoolId() external view returns (bytes32);

    function getSwapFeePercentage() external view returns (uint256);

    function getLastJoinExitData()
        external
        view
        returns (uint256 lastJoinExitAmplification, uint256 lastPostJoinExitInvariant);

    function getLastInvariant()
        external
        view
        returns (uint256 lastInvariant, uint256 lastInvariantAmp);

    function getActualSupply() external view returns (uint256);

    function getAmplificationParameter()
        external
        view
        returns (
            uint256,
            bool,
            uint256
        );

    function getScalingFactors() external view returns (uint256[] memory);

    function getBptIndex() external view returns (uint256);

    function isTokenExemptFromYieldProtocolFee(IERC20 token) external view returns (bool);

    function getRateProviders() external view returns (address[] memory);

    function getTokenRateCache(IERC20 token)
        external
        view
        returns (
            uint256 rate,
            uint256 oldRate,
            uint256 duration,
            uint256 expires
        );

    function getProtocolFeePercentageCache(uint256 feeType) external view returns (uint256);

    function getPausedState()
        external
        view
        returns (
            bool,
            uint256,
            uint256
        );

    function inRecoveryMode() external view returns (bool);
}
