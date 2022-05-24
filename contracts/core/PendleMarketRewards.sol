// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./PendleBaseToken.sol";
import "../interfaces/IPPrincipalToken.sol";
import "../SuperComposableYield/ISuperComposableYield.sol";
import "./LiquidityMining/PendleGauge.sol";
import "./PendleMarket.sol";

import "../interfaces/IPMarket.sol";
import "../interfaces/IPMarketFactory.sol";
import "../interfaces/IPMarketSwapCallback.sol";
import "../interfaces/IPMarketAddRemoveCallback.sol";

import "../libraries/math/LogExpMath.sol";
import "../libraries/math/Math.sol";
import "../libraries/math/MarketMathAux.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// solhint-disable reason-string
contract PendleMarketRewards is PendleGauge, PendleMarket {
    bool private _removeEmergency;

    constructor(
        address _PT,
        int256 _scalarRoot,
        int256 _initialAnchor,
        address _vePendle,
        address _gaugeController
    ) PendleMarket(_PT, _scalarRoot, _initialAnchor) PendleGauge(_vePendle, _gaugeController) {}

    function getRewardTokens() public view override returns (address[] memory rewardTokens) {
        address[] memory SCYRewards = ISuperComposableYield(SCY).getRewardTokens();
        rewardTokens = new address[](SCYRewards.length + 1);
        rewardTokens[0] = pendle;
        for (uint256 i = 0; i < SCYRewards.length; ++i) {
            rewardTokens[i + 1] = SCYRewards[i];
        }
    }

    function removeLiquidityEmergency(address receiver, bytes calldata data)
        external
        nonReentrant
        returns (uint256 scyToAccount, uint256 ptToAccount)
    {
        uint256 balance = balanceOf(msg.sender);
        _beforeEmergencyRemoveLiquidity(user);

        _removeEmergency = true;
        (scyToAccount, ptToAccount) = removeLiquidity(receiver, balance, data);
        _removeEmergency = false;
    }

    function _stakedBalance(address user) internal view override returns (uint256) {
        return balanceOf(user);
    }

    function _totalStaked() internal view override returns (uint256) {
        return totalSupply();
    }

    function _redeemExternalReward() internal override {
        ISuperComposableYield(SCY).redeemReward(address(this));
        super._redeemExternalReward();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        if (_removeEmergency) return;
        _updateGlobalReward();
        if (from != address(0)) {
            _updateUserRewardSkipGlobal(from);
        }
        if (to != address(0)) {
            _updateUserRewardSkipGlobal(to);
        }
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        if (_removeEmergency) return;
        if (from != address(0)) {
            _updateUserActiveBalance(from);
        }
        if (to != address(0)) {
            _updateUserActiveBalance(to);
        }
    }
}
