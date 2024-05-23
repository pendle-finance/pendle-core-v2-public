// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDolomiteMarginProxy {
    enum BalanceCheckFlag {
        Both,
        From,
        To,
        None
    }

    function depositWeiIntoDefaultAccount(uint256 _marketId, uint256 _amountWei) external;

    function withdrawParFromDefaultAccount(
        uint256 _marketId,
        uint256 _amountPar,
        BalanceCheckFlag _balanceCheckFlag
    ) external;
}
