//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IEulerVault, AmountCap, NO_CAP} from "./dependencies/IEulerVault.sol";
import {IEulerFactory} from "./dependencies/IEulerFactory.sol";
import {EulerMMPayloadLib} from "./EulerMMPayloadLib.sol";

import {BaseMoneyMarketView} from "../../BaseMoneyMarketView.sol";
import {IPLoopPositionBox, BoxData} from "../../../../interfaces/IPLoopPositionBox.sol";
import {Reward} from "../../../../interfaces/IMoneyMarketView.sol";
import {PMath} from "../../../../core/libraries/math/PMath.sol";

contract EulerMoneyMarketView is BaseMoneyMarketView {
    using EulerMMPayloadLib for IEulerFactory;
    using PMath for uint256;

    IEulerFactory public immutable FACTORY;

    constructor(string memory _moneyMarketName, address _ptLooper, address _factory)
        BaseMoneyMarketView(_moneyMarketName, _ptLooper)
    {
        FACTORY = IEulerFactory(_factory);
    }

    /// @notice Known limitation: during a governance LTV ramp this returns the target liquidation LTV, which is
    /// lower than the one in effect. Safe, but callers can react early.
    function _thresholds(IPLoopPositionBox, BoxData memory bd)
        internal
        view
        virtual
        override
        returns (uint256 ltv, uint256 liquidationThreshold)
    {
        IEulerVault baseVault = FACTORY.baseVault(bd.mmPayload);
        IEulerVault quoteVault = FACTORY.quoteVault(bd.mmPayload);

        (uint256 borrowLTV, uint256 liquidationLTV,,,) = quoteVault.LTVFull(baseVault);

        // bps to WAD
        ltv = borrowLTV * 1e14;
        liquidationThreshold = liquidationLTV * 1e14;
    }

    function _liquidity(IPLoopPositionBox, BoxData memory bd)
        internal
        view
        virtual
        override
        returns (uint256 borrowing, uint256 lending)
    {
        IEulerVault baseVault = FACTORY.baseVault(bd.mmPayload);
        IEulerVault quoteVault = FACTORY.quoteVault(bd.mmPayload);

        lending = PMath.min(baseVault.maxDeposit(address(0)), IERC20(bd.spokePt).totalSupply());

        (, AmountCap borrowCapAmt) = quoteVault.caps();
        uint256 borrowCap = borrowCapAmt.resolve();
        uint256 quoteVaultCash = quoteVault.cash();

        if (borrowCap == NO_CAP) {
            borrowing = quoteVaultCash;
        } else {
            uint256 borrowRemain = borrowCap.subMax0(quoteVault.totalBorrows());
            borrowing = PMath.min(quoteVaultCash, borrowRemain);
        }
    }

    function _rates(IPLoopPositionBox, BoxData memory bd)
        internal
        view
        virtual
        override
        returns (uint256 borrowing, uint256 lending)
    {
        borrowing = _borrowingApy(FACTORY.quoteVault(bd.mmPayload));
        lending = _supplyApy(FACTORY.baseVault(bd.mmPayload));
    }

    function _borrowingApy(IEulerVault vault) internal view returns (uint256) {
        // Per-second rate, RAY to WAD.
        return _apy({rate: vault.interestRate() / 1e9, perSeconds: 1});
    }

    uint256 private constant EULER_CONFIG_SCALE = 1e4;

    // See Euler's `UtilLens._computeAPYs`: https://github.com/euler-xyz/evk-periphery/blob/6e41cbec944920b30dfcccbcbfb563b4c4d3d932/src/Lens/Utils.sol#L106
    function _supplyApy(IEulerVault vault) internal view returns (uint256) {
        uint256 borrows = vault.totalBorrows();
        uint256 totalAssets = vault.cash() + borrows;
        if (totalAssets == 0) return 0;

        uint256 borrowingApy = _borrowingApy(vault);
        uint256 interestFee = vault.interestFee();

        // Same formula: https://github.com/euler-xyz/evk-periphery/blob/6e41cbec944920b30dfcccbcbfb563b4c4d3d932/src/Lens/Utils.sol#L120
        return borrowingApy * borrows * (EULER_CONFIG_SCALE - interestFee) / totalAssets / EULER_CONFIG_SCALE;
    }
}
