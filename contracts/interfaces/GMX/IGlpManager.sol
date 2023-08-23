// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGlpManager {
    function getAumInUsdg(bool maximise) external view returns (uint256);

    function vault() external view returns (address);

    function gov() external view returns (address);

    function setCooldownDuration(uint256 _cooldownDuration) external;

    function getPrice(bool _maximise) external view returns (uint256);
}
