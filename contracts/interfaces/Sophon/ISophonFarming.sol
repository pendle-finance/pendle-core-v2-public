// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ISophonFarming {
    function pendingPoints(uint256 _pid, address _user) external view returns (uint256);

    function transferPoints(uint256 _pid, address _sender, address _receiver, uint256 _transferAmount) external;

    function poolInfo(
        uint256 _pid
    )
        external
        view
        returns (address, address, uint256, uint256, uint256, uint256, uint256, uint256, uint256, string memory);

    function deposit(uint256 _pid, uint256 _amount, uint256 _boostAmount) external;

    function withdraw(uint256 _pid, uint256 _withdrawAmount) external;
}
