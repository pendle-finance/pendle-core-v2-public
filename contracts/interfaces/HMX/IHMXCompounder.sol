// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IHMXCompounder {
    function compound(
        address[] memory pools,
        address[][] memory rewarders,
        uint256 startEpochTimestamp,
        uint256 noOfEpochs,
        uint256[] calldata tokenIds
    ) external;
}
