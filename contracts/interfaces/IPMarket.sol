// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IPBaseToken.sol";
import "../libraries/math/MarketMathLib.sol";

interface IPMarket is IPBaseToken {
    function addLiquidity(
        address recipient,
        uint256 scyDesired,
        uint256 otDesired,
        bytes calldata data
    )
        external
        returns (
            uint256 lpToAccount,
            uint256 scyUsed,
            uint256 otUsed
        );

    function removeLiquidity(
        address recipient,
        uint256 lpToRemove,
        bytes calldata data
    ) external returns (uint256 scyToAccount, uint256 otToAccount);

    function swapExactOtForSCY(
        address recipient,
        uint256 exactOtIn,
        uint256 minSCYOut,
        bytes calldata data
    ) external returns (uint256 netSCYOut, uint256 netSCYToReserve);

    function swapSCYForExactOt(
        address recipient,
        uint256 exactOtOut,
        uint256 maxSCYIn,
        bytes calldata data
    ) external returns (uint256 netSCYIn, uint256 netSCYToReserve);

    function readState() external returns (MarketParameters memory market);

    function OT() external view returns (address);

    function YT() external view returns (address);

    function SCY() external view returns (address);

    function readTokens()
        external
        view
        returns (
            ISuperComposableYield _SCY,
            IPOwnershipToken _OT,
            IPYieldToken _YT
        );
}
