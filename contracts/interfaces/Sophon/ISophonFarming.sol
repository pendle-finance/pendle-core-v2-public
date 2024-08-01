// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ISophonFarming {
    struct PoolInfo {
        address lpToken; // Address of LP token contract.
        address l2Farm; // Address of the farming contract on Sophon chain
        uint256 amount; // total amount of LP tokens earning yield from deposits and boosts
        uint256 boostAmount; // total boosted value purchased by users
        uint256 depositAmount; // remaining deposits not applied to a boost purchases
        uint256 allocPoint; // How many allocation points assigned to this pool. Points to distribute per block.
        uint256 lastRewardBlock; // Last block number that points distribution occurs.
        uint256 accPointsPerShare; // Accumulated points per share, times 1e18. See below.
        string description; // Description of pool.
    }

    function pendingPoints(uint256 _pid, address _user) external view returns (uint256);

    function transferPoints(uint256 _pid, address _sender, address _receiver, uint256 _transferAmount) external;

    function poolInfo(uint256 _pid) external view returns (PoolInfo memory);

    function deposit(uint256 _pid, uint256 _amount, uint256 _boostAmount) external;

    function withdraw(uint256 _pid, uint256 _withdrawAmount) external;
}
