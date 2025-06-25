// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./PendleLPWrapper.sol";
import "../core/libraries/BoringOwnableUpgradeableV2.sol";

contract PendleLPWrapperFactory is BoringOwnableUpgradeableV2 {
    event LPWrapperCreated(address indexed lpToken, address indexed wrapper);
    event RewardReceiverSet(address indexed newReceiver);

    mapping(address LP => address wrapper) public wrappers;

    address public rewardReceiver;

    constructor(address _rewardReceiver) initializer {
        __BoringOwnableV2_init(msg.sender);
        _setRewardReceiver(_rewardReceiver);
    }

    function create(address LP) external onlyOwner returns (address wrapper) {
        require(wrappers[LP] == address(0), "Wrapper already exists");
        wrapper = address(new PendleLPWrapper(LP));
        wrappers[LP] = wrapper;

        emit LPWrapperCreated(LP, wrapper);
    }

    /// @dev anyone can call, it's a no-downside function
    function redeemRewardsAndTransfer(address[] memory _wrappers) external {
        for (uint256 i = 0; i < _wrappers.length; i++) {
            PendleLPWrapper(_wrappers[i]).redeemRewardsAndTransfer(rewardReceiver);
        }
    }

    // ------------------------------ ADMIN FUNCTIONS ------------------------------

    function setRewardReceiver(address _rewardReceiver) external onlyOwner {
        _setRewardReceiver(_rewardReceiver);
    }

    function _setRewardReceiver(address _rewardReceiver) internal {
        rewardReceiver = _rewardReceiver;
        emit RewardReceiverSet(rewardReceiver);
    }

    function setRewardRedemptionDisabled(address _wrapper, bool _isRewardRedemptionDisabled) external onlyOwner {
        PendleLPWrapper(_wrapper).setRewardRedemptionDisabled(_isRewardRedemptionDisabled);
    }
}
