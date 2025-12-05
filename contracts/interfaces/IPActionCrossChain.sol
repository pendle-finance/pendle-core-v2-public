// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {TokenOutput} from "./IPAllActionTypeV3.sol";

interface IPActionCrossChain {
    function swapWithFixedPricePTAMM(
        address receiver,
        address fixedPricePTAMM,
        address PT,
        uint256 exactPtIn,
        TokenOutput calldata out
    ) external returns (uint256 netTokenOut);
}
