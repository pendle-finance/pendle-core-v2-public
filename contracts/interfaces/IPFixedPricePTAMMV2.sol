// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {IPChainlinkOracleEssential} from "../interfaces/IPChainlinkOracleEssential.sol";
import {
    IERC20MetadataUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

interface IPFixedPricePTAMMV2 is IERC20MetadataUpgradeable {
    event Swap(address indexed caller, address indexed receiver, address PT, uint256 netPtIn, uint256 netTokenOut);

    event PriceOracleUpdated(address indexed PT, address indexed priceOracle);

    event TokenFunded(address indexed sender, uint256 amount);

    event TokenWithdrawn(address indexed sender, uint256 amount);

    event WhitelistUpdated(address indexed user, bool isWhitelisted);

    event PauseStatusUpdated(address indexed PT, bool isPaused);

    function outputToken() external view returns (address);

    function priceOracle(address PT)
        external
        view
        returns (bool isPaused, IPChainlinkOracleEssential, uint256 multiplier);

    function totalPt(address PT) external view returns (uint256);

    function isWhitelisted(address user) external view returns (bool);

    function previewSwapExactPtForToken(address PT, uint256 exactPtIn) external view returns (uint256 amountTokenOut);

    function swapExactPtForToken(address receiver, address PT, uint256 exactPtIn, bytes calldata data)
        external
        returns (uint256 netTokenOut);

    // Add/remove funds

    function addFundWhitelisted(uint256 amount) external;

    function removeFund(uint256 amount) external;

    // Admin functions

    function withdrawPt(address PT, uint256 amount) external;

    function setWhitelist(address user, bool isWhitelisted) external;

    function setPriceOracle(address PT, address priceOracle, uint256 multiplier) external;

    function setPausePtTrading(address PT, bool isPaused) external;
}

interface IPFixedPricePTAMMSwapCallback {
    function swapCallback(uint256 exactTokenOut, uint256 netPtIn, bytes calldata data) external;
}
