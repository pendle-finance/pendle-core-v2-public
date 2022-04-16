// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./IPBaseToken.sol";
import "./IPOwnershipToken.sol";
import "./IPYieldToken.sol";
import "../libraries/math/MarketMathCore.sol";

interface IPMarket is IPBaseToken {
    function addLiquidity(
        address receiver,
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
        address receiver,
        uint256 lpToRemove,
        bytes calldata data
    ) external returns (uint256 scyToAccount, uint256 otToAccount);

    function swapExactOtForScy(
        address receiver,
        uint256 exactOtIn,
        uint256 minScyOut,
        bytes calldata data
    ) external returns (uint256 netScyOut, uint256 netScyToReserve);

    function swapScyForExactOt(
        address receiver,
        uint256 exactOtOut,
        uint256 maxScyIn,
        bytes calldata data
    ) external returns (uint256 netScyIn, uint256 netScyToReserve);

    function readState() external view returns (MarketAllParams memory market);

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
