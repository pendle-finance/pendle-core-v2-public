//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IMorpho, MorphoMarketId, MarketParams, Market as MorphoMarketState} from "./dependencies/IMorpho.sol";
import {BaseMoneyMarketView} from "../../BaseMoneyMarketView.sol";
import {IPLoopPositionBox, BoxData} from "../../../../interfaces/IPLoopPositionBox.sol";
import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract MorphoBlueMoneyMarketView is BaseMoneyMarketView {
    IMorpho public immutable MORPHO;

    constructor(string memory _moneyMarketName, address _ptLooper, address _morpho)
        BaseMoneyMarketView(_moneyMarketName, _ptLooper)
    {
        MORPHO = IMorpho(_morpho);
    }

    // ========== IMoneyMarketView ==========

    // `_moneyMarketBalances` is inherited from `BaseMoneyMarketView`, which reads the
    // canonical `collateralBalance` / `debtBalance` off the spoke MM clone (the latter accrues
    // interest before reading) — no need to re-implement Morpho's shares math here.

    function _thresholds(IPLoopPositionBox, BoxData memory bd)
        internal
        view
        virtual
        override
        returns (uint256 ltv, uint256 liquidationThreshold)
    {
        // Morpho has a single LLTV, so ltv == liquidationThreshold
        ltv = liquidationThreshold = MORPHO.idToMarketParams(_morphoMarketId(bd)).lltv;
    }

    function _liquidity(IPLoopPositionBox, BoxData memory bd)
        internal
        view
        virtual
        override
        returns (uint256 borrowing, uint256 lending)
    {
        MorphoMarketState memory market = MORPHO.market(_morphoMarketId(bd));
        borrowing = market.totalSupplyAssets - market.totalBorrowAssets;
        lending = IERC20(bd.spokePt).totalSupply();
    }

    function _rates(IPLoopPositionBox, BoxData memory bd)
        internal
        view
        virtual
        override
        returns (uint256 borrowing, uint256 lending)
    {
        MorphoMarketId marketId = _morphoMarketId(bd);
        MarketParams memory params = MORPHO.idToMarketParams(marketId);

        borrowing = _apy({rate: params.irm.borrowRateView(params, MORPHO.market(marketId)), perSeconds: 1});
        lending = 0;
    }

    // ========== Other internal helpers ==========

    function _morphoMarketId(BoxData memory bd) internal pure returns (MorphoMarketId) {
        return MorphoMarketId.wrap(bd.mmPayload);
    }
}
