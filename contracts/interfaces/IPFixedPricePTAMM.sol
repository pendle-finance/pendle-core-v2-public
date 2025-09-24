// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {IPBridgedPrincipalToken} from "./IPBridgedPrincipalToken.sol";
import {IPChainlinkOracleEssential} from "../interfaces/IPChainlinkOracleEssential.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPFixedPricePTAMM {
    event Swap(
        address indexed caller,
        address indexed receiver,
        address PT,
        uint256 netPtIn,
        address token,
        uint256 netTokenOut
    );

    event PriceOracleUpdated(address indexed PT, address indexed token, address indexed priceOracle);

    event Seeded(address indexed token, uint256 amount);
    event Unseeded(address indexed token, uint256 amount);

    function priceOracle(
        address PT,
        address token
    ) external view returns (IPChainlinkOracleEssential, uint256 multiplier);

    function previewSwapPtForExactToken(
        address PT,
        address token,
        uint256 exactTokenOut
    ) external view returns (uint256 amountPtIn);

    function previewSwapExactPtForToken(
        address PT,
        uint256 exactPtIn,
        address token
    ) external view returns (uint256 amountTokenOut);

    function swapPtForExactToken(
        address receiver,
        address PT,
        address token,
        uint256 exactTokenOut,
        bytes calldata data
    ) external returns (uint256 netPtIn);

    function swapExactPtForToken(
        address receiver,
        address PT,
        uint256 exactPtIn,
        address token,
        bytes calldata data
    ) external returns (uint256 netTokenOut);

    function transferInThenSwapPtForExactToken(
        address receiver,
        address PT,
        address token,
        uint256 exactTokenOut
    ) external returns (uint256 netPtIn);

    function transferInThenSwapExactPtForToken(
        address receiver,
        address PT,
        uint256 exactPtIn,
        address token
    ) external returns (uint256 netPtIn);

    // Admin functions

    function setPriceOracle(address PT, address token, address priceOracle, uint256 multiplier) external;

    function addFund(address token, uint256 amount) external payable;

    function removeFund(address token, uint256 amount) external;
}

interface IPFixedPricePTAMMSwapCallback {
    function swapCallback(uint256 exactTokenOut, uint256 netPtIn, bytes calldata data) external;
}
