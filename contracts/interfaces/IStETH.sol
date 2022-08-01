// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface IStETH {
    function getSharesByPooledEth(uint256 _ethAmount) external view returns (uint256);

    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);

    function submit(address referral) external payable returns (uint256 amount);

    function burnShares(address _account, uint256 _sharesAmount)
        external
        returns (uint256 newTotalShares);
}
