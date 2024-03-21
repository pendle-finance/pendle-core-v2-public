// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ITensorplexStTAO {
    function wrappedToken() external view returns (address);

    function wrap(uint256 wtaoAmount) external;

    function exchangeRate() external view returns (uint256);

    function maxTaoForWrap() external view returns (uint256);

    function calculateAmtAfterFee(uint256 wtaoAmount) external view returns (uint256, uint256);

    function getWstTAObyWTAO(uint256 wtaoAmount) external view returns (uint256);
}
