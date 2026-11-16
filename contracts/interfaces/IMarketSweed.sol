// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IPAllActionV3.sol";

interface IMarketSweed {
    struct ApproxSweedParams {
        uint256 targetLnImpliedRate;
        uint256 eps;
        uint256 maxPtToSwap;
        int256 guessOffchain;
        uint256 maxIteration;
    }

    function seedAtImpliedRate(
        address receiver,
        address market,
        uint256 minLpOut,
        uint256 minYtOut,
        TokenInput calldata input,
        ApproxSweedParams calldata sweedParams
    ) external payable returns (uint256 netLpOut, uint256 netYtOut, int256 guessedAmountPtToSwap);
}
