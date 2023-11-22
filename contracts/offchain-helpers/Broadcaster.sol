// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../interfaces/IPVotingController.sol";
import "../LiquidityMining/libraries/WeekMath.sol";
import "../core/libraries/BoringOwnableUpgradeable.sol";
import "../core/libraries/TokenHelper.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";

contract Broadcaster is Initializable, BoringOwnableUpgradeable, UUPSUpgradeable, TokenHelper {
    IPVotingController public immutable votingController;
    uint256 public lastBroadcastedWeek;

    constructor(address _votingController) initializer {
        votingController = IPVotingController(_votingController);
    }

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function finalizeAndBroadcast(uint64[] calldata chainIds) external {
        uint256 currentWeek = WeekMath.getCurrentWeekStart();
        require(lastBroadcastedWeek < currentWeek, "current week already broadcasted");
        lastBroadcastedWeek = currentWeek;

        votingController.finalizeEpoch();
        for (uint256 i = 0; i < chainIds.length; ) {
            uint64 chainId = chainIds[i];
            uint256 fee = votingController.getBroadcastResultFee(chainId);
            votingController.broadcastResults{value: fee}(chainId);
            unchecked {
                i++;
            }
        }
    }

    function withdrawETH() external onlyOwner {
        _transferOut(NATIVE, owner, address(this).balance);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    receive() external payable {}
}
