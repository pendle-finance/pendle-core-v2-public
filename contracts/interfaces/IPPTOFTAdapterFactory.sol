// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPPTOFTAdapterFactory {
    event PtAdapterCreated(address indexed pt, address indexed adapter);

    function initialize(address _owner) external;

    function createPtAdapter(address pt) external returns (address);

    function ptAdapter(address pt) external view returns (address);
}
