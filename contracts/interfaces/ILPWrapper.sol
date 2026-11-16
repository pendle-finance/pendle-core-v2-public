// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

interface ILPWrapper {
    function LP() external view returns (address);

    function factory() external view returns (address);

    function isRewardRedemptionDisabled() external view returns (bool);

    function setRewardRedemptionDisabled(bool _isRewardRedemptionDisabled) external;

    function wrap(address receiver, uint256 netLpIn) external;

    function unwrap(address receiver, uint256 netWrapIn) external;
}
