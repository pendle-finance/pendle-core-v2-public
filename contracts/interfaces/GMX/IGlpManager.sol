// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IGlpManager {
    function getAumInUsdg(bool maximise) external view returns (uint256);

    function vault() external view returns (address);
}
