// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IThenaFactory {
    function allPairsLength() external view returns (uint);

    function isPair(address pair) external view returns (bool);

    function allPairs(uint index) external view returns (address);

    function pairCodeHash() external pure returns (bytes32);

    function getPair(address tokenA, address token, bool stable) external view returns (address);

    function createPair(address tokenA, address tokenB, bool stable) external returns (address pair);

    function getFee(bool _stable) external view returns (uint256);
}
