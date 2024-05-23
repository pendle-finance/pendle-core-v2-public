// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDolomiteMarginContract {
    struct Info {
        address owner;
        uint256 number;
    }

    struct Wei {
        bool sign;
        uint256 value;
    }

    struct Index {
        uint112 borrow;
        uint112 supply;
        uint32 lastUpdate;
    }

    function getMarketIdByTokenAddress(address token) external view returns (uint256);

    function getMarketCurrentIndex(uint256 marketId) external view returns (Index memory);

    function getAccountPar(Info calldata account, uint256 marketId) external view returns (Wei memory);
}
