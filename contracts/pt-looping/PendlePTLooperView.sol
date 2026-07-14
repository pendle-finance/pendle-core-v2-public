//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IPLoopPositionBoxFactory} from "../interfaces/IPLoopPositionBoxFactory.sol";
import {IMoneyMarketView} from "../interfaces/IMoneyMarketView.sol";
import {BoringOwnableUpgradeableV2} from "../core/libraries/BoringOwnableUpgradeableV2.sol";
import {IPLoopPositionBox, BoxData} from "../interfaces/IPLoopPositionBox.sol";
import {IPPTLooperView, PositionView} from "../interfaces/IPPTLooperView.sol";

contract PendlePTLooperView is IPPTLooperView, BoringOwnableUpgradeableV2 {
    IPLoopPositionBoxFactory public immutable POSITION_BOX_FACTORY;

    mapping(address spokeMMBeacon => IMoneyMarketView) public moneyMarketView;

    constructor(address _positionBoxFactory) {
        _disableInitializers();
        POSITION_BOX_FACTORY = IPLoopPositionBoxFactory(_positionBoxFactory);
    }

    function initialize(address _owner) external initializer {
        __BoringOwnableV2_init(_owner);
    }

    function getAll(address owner, bytes32 boxId) external returns (PositionView memory v) {
        (IPLoopPositionBox box,, BoxData memory bd) = POSITION_BOX_FACTORY.deployPositionBoxAndMoneyMarket(owner, boxId);
        IMoneyMarketView mmView = moneyMarketView[bd.spokeMMBeacon];

        (v.mmPtBalance, v.mmDebtBalance) = mmView.moneyMarketBalances(box);
        (v.ltv, v.liquidationThreshold) = mmView.thresholds(box);
        (v.borrowingLiquidity, v.lendingLiquidity) = mmView.liquidity(box);
        (v.borrowingRewards, v.lendingRewards) = mmView.rewards(box);
        v.limits = mmView.limits(box);
        (v.borrowingRate, v.lendingRate) = mmView.rates(box);
        v.ptDebtRateWad = mmView.ptDebtRate(box);
    }

    // ========== Admin functions ==========
    function registerMoneyMarketView(address spokeMM, address mmView) external onlyOwner {
        moneyMarketView[spokeMM] = IMoneyMarketView(mmView);
        emit MoneyMarketViewRegistered(spokeMM, mmView);
    }
}
