// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./IPBaseToken.sol";
import "./IPPrincipalToken.sol";
import "./IPYieldToken.sol";
import "../libraries/math/MarketMathCore.sol";

interface IPMarket is IPBaseToken {
    event AddLiquidity(
        address indexed receiver,
        uint256 lpToAccount,
        uint256 scyUsed,
        uint256 otUsed
    );

    event RemoveLiquidity(
        address indexed receiver,
        uint256 lpRemoved,
        uint256 scyToAccount,
        uint256 otToAccount
    );

    event Swap(
        address indexed receiver,
        int256 otToAccount,
        int256 scyToAccount,
        uint256 netScyToReserve
    );

    event UpdateImpliedRate(uint256 indexed timestamp, uint256 lnLastImpliedRate);

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

    function swapExactPtForScy(
        address receiver,
        uint256 exactPtIn,
        uint256 minScyOut,
        bytes calldata data
    ) external returns (uint256 netScyOut, uint256 netScyToReserve);

    function swapScyForExactPt(
        address receiver,
        uint256 exactPtOut,
        uint256 maxScyIn,
        bytes calldata data
    ) external returns (uint256 netScyIn, uint256 netScyToReserve);

    function readState(bool updateRateOracle) external view returns (MarketState memory market);

    function PT() external view returns (address);

    function YT() external view returns (address);

    function SCY() external view returns (address);

    function readTokens()
        external
        view
        returns (
            ISuperComposableYield _SCY,
            IPPrincipalToken _OT,
            IPYieldToken _YT
        );
}
