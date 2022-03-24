// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IPBaseToken.sol";
import "../libraries/math/MarketMathLib.sol";

interface IPMarket is IPBaseToken {
    function addLiquidity(
        address recipient,
        uint256 lytDesired,
        uint256 otDesired,
        bytes calldata data
    )
        external
        returns (
            uint256 lpToUser,
            uint256 lytUsed,
            uint256 otUsed
        );

    function removeLiquidity(
        address recipient,
        uint256 lpToRemove,
        bytes calldata data
    ) external returns (uint256 lytOut, uint256 otOut);

    function swap(
        address recipient,
        int256 otToAccount,
        bytes calldata data
    ) external returns (int256 netLytToAccount);

    function readState() external returns (MarketParameters memory market);

    function OT() external view returns (address);

    function LYT() external view returns (address);

    function timeToExpiry() external view returns (uint256);
}
