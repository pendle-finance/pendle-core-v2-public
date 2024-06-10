// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDolomiteMarginContract {
    struct Index {
        uint96 borrow;
        uint96 supply;
        uint32 lastUpdate;
    }

    function getMarketIdByTokenAddress(address token) external view returns (uint256);

    function getMarketCurrentIndex(uint256 marketId) external view returns (Index memory);
}
