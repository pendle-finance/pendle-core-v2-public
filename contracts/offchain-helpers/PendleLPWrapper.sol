// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../core/erc20/PendleERC20.sol";
import "../core/libraries/TokenHelper.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPLPWrapperFactory.sol";
import "../interfaces/ILPWrapper.sol";

contract PendleLPWrapper is PendleERC20, TokenHelper, ILPWrapper {
    address public immutable LP;
    address public immutable factory;
    bool public isRewardRedemptionDisabled;

    modifier onlyFactory() {
        require(msg.sender == factory, "PendleLPWrapper: not factory");
        _;
    }

    constructor(address _lpToken) PendleERC20("Pendle Market Wrapped", "PENDLE-LPT-WRAPPED", 18) {
        LP = _lpToken;
        factory = msg.sender;
    }

    function wrap(address receiver, uint256 netLpIn) external nonReentrant {
        _transferIn(LP, msg.sender, netLpIn);
        _mint(receiver, netLpIn);
    }

    function unwrap(address receiver, uint256 netWrapIn) external nonReentrant {
        _burn(msg.sender, netWrapIn);
        _transferOut(LP, receiver, netWrapIn);
    }

    function _beforeTokenTransfer(address /*from*/, address /*to*/, uint256 /*amount*/) internal override {
        if (!isRewardRedemptionDisabled) {
            IPMarket(LP).redeemRewards(address(this));
        }
    }

    function setRewardRedemptionDisabled(bool _isRewardRedemptionDisabled) external onlyFactory {
        isRewardRedemptionDisabled = _isRewardRedemptionDisabled;
    }

    function redeemRewardsAndTransfer(address receiver) external onlyFactory {
        IPMarket(LP).redeemRewards(address(this));
        address[] memory rewardTokens = IPMarket(LP).getRewardTokens();
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            _transferOut(rewardTokens[i], receiver, _selfBalance(rewardTokens[i]));
        }
    }
}
