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
            uint256 lpToAccount,
            uint256 lytUsed,
            uint256 otUsed
        );

    function removeLiquidity(
        address recipient,
        uint256 lpToRemove,
        bytes calldata data
    ) external returns (uint256 lytToAccount, uint256 otToAccount);

    function swapExactOtForLyt(
        address recipient,
        uint256 exactOtIn,
        uint256 minLytOut,
        bytes calldata data
    ) external returns (uint256 netLytOut, uint256 netLytToReserve);

    function swapLytForExactOt(
        address recipient,
        uint256 exactOtOut,
        uint256 maxLytIn,
        bytes calldata data
    ) external returns (uint256 netLytIn, uint256 netLytToReserve);

    function readState() external returns (MarketParameters memory market);

    function OT() external view returns (address);

    function LYT() external view returns (address);

    function timeToExpiry() external view returns (uint256);
}
