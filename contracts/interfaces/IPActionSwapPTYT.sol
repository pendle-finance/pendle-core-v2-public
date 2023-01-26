// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../router/base/MarketApproxLib.sol";
import "../router/base/ActionBaseMintRedeem.sol";

interface IPActionSwapPTYT {
    event SwapPtAndYt(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        int256 netPtToAccount,
        int256 netYtToAccount
    );

    function swapExactPtForYt(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minYtOut,
        ApproxParams calldata guessTotalPtToSwap
    ) external returns (uint256 netYtOut, uint256 netSyFee);

    function swapExactYtForPt(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minPtOut,
        ApproxParams calldata guessTotalPtSwapped
    ) external returns (uint256 netPtOut, uint256 netSyFee);
}
