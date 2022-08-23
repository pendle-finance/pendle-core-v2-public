// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./IPPrincipalToken.sol";
import "./IPYieldToken.sol";
import "./ISuperComposableYield.sol";
import "../libraries/math/MarketMathCore.sol";
import "./IPGauge.sol";

interface IPMarket is IERC20Metadata, IPGauge {
    event Mint(address indexed receiver, uint256 lpMinted, uint256 scyUsed, uint256 ptUsed);

    event Burn(
        address indexed receiverScy,
        address indexed receiverPt,
        uint256 lpBurned,
        uint256 scyToAccount,
        uint256 ptToAccount
    );

    event Swap(
        address indexed receiver,
        int256 ptToAccount,
        int256 scyToAccount,
        uint256 netScyToReserve
    );

    event UpdateImpliedRate(uint256 indexed timestamp, uint256 lnLastImpliedRate);

    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld,
        uint16 observationCardinalityNextNew
    );

    function mint(address receiver) external returns (uint256);

    function burn(address receiverScy, address receiverPt)
        external
        returns (uint256 scyToAccount, uint256 ptToAccount);

    function swapExactPtForScy(
        address receiver,
        uint256 exactPtIn,
        bytes calldata data
    ) external returns (uint256 netScyOut, uint256 netScyToReserve);

    function swapScyForExactPt(
        address receiver,
        uint256 exactPtOut,
        bytes calldata data
    ) external returns (uint256 netScyIn, uint256 netScyToReserve);

    function redeemRewards(address user) external returns (uint256[] memory);

    function readState() external view returns (MarketState memory market);

    function observe(uint32[] memory secondsAgos)
        external
        view
        returns (uint216[] memory lnImpliedRateCumulative);

    function increaseObservationsCardinalityNext(uint16 cardinalityNext) external;

    function readTokens()
        external
        view
        returns (
            ISuperComposableYield _SCY,
            IPPrincipalToken _PT,
            IPYieldToken _YT
        );

    function getRewardTokens() external view returns (address[] memory);

    function isExpired() external view returns (bool);
}
