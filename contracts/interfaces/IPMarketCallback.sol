// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPMarketCallback {
    function callback(
        int256 amountOTIn,
        int256 amountLYTIn,
        bytes calldata cbData
    ) external returns (bytes memory cbRes);
}
