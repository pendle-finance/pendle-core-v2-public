// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPMarketAddRemoveCallback.sol";
import "../../interfaces/IPMarketSwapCallback.sol";
import "../../libraries/SCYUtils.sol";
import "../../libraries/math/MarketApproxLib.sol";
import "../../libraries/math/MarketMathAux.sol";
import "./base/ActionSCYAndPYBase.sol";
import "./base/ActionType.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ActionCallback is IPMarketSwapCallback, ActionType {
    address public immutable marketFactory;
    using Math for int256;
    using Math for uint256;
    using SafeERC20 for ISuperComposableYield;
    using SafeERC20 for IPYieldToken;
    using SafeERC20 for IERC20;

    modifier onlyPendleMarket(address market) {
        require(IPMarketFactory(marketFactory).isValidMarket(market), "INVALID_MARKET");
        _;
    }

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _marketFactory) {
        require(_marketFactory != address(0), "zero address");
        marketFactory = _marketFactory;
    }

    /**
     * @dev The callback is only callable by a Pendle Market created by the factory
     */
    function swapCallback(
        int256 ptToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) external override onlyPendleMarket(msg.sender) {
        (ACTION_TYPE swapType, ) = abi.decode(data, (ACTION_TYPE, address));
        if (swapType == ACTION_TYPE.SwapExactScyForYt) {
            _swapExactScyForYt_callback(msg.sender, ptToAccount, scyToAccount, data);
        } else if (swapType == ACTION_TYPE.SwapSCYForExactYt) {
            _swapScyForExactYt_callback(msg.sender, ptToAccount, scyToAccount, data);
        } else if (
            swapType == ACTION_TYPE.SwapYtForExactScy || swapType == ACTION_TYPE.SwapExactYtForScy
        ) {
            _swapYtForScy_callback(msg.sender, ptToAccount, scyToAccount, data);
        } else if (swapType == ACTION_TYPE.SwapPtForYt) {
            _swapPtForYt_callback(msg.sender, ptToAccount, scyToAccount, data);
        } else if (swapType == ACTION_TYPE.SwapYtForPt) {
            _swapYtForPt_callback(msg.sender, ptToAccount, scyToAccount, data);
        } else {
            require(false, "unknown swapType");
        }
    }

    function _swapExactScyForYt_callback(
        address market,
        int256 ptToAccount,
        int256, /*scyToAccount*/
        bytes calldata data
    ) internal {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        (, address receiver) = abi.decode(data, (ACTION_TYPE, address));

        uint256 ptOwed = ptToAccount.abs();
        uint256 amountPYout = YT.mintPY(market, receiver);

        require(amountPYout >= ptOwed, "insufficient pt to pay");
    }

    function _swapScyForExactYt_callback(
        address market,
        int256 ptToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        (, address payer, address receiver) = abi.decode(data, (ACTION_TYPE, address, address));
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 ptOwed = ptToAccount.neg().Uint();
        uint256 scyReceived = scyToAccount.Uint();

        // ptOwed = totalAsset
        uint256 scyIndex = SCY.exchangeRateCurrent();
        uint256 scyNeedTotal = SCYUtils.assetToScy(scyIndex, ptOwed);
        scyNeedTotal += scyIndex.rawDivUp(SCYUtils.ONE);

        {
            uint256 netScyToPull = scyNeedTotal.subMax0(scyReceived);
            SCY.safeTransferFrom(payer, address(YT), netScyToPull);
        }

        uint256 amountPYout = YT.mintPY(market, receiver);

        require(amountPYout >= ptOwed, "insufficient pt to pay");
    }

    /**
    @dev receive PT -> pair with YT to redeem SCY -> payback SCY
    */
    function _swapYtForScy_callback(
        address market,
        int256, /*ptToAccount*/
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        (, address receiver) = abi.decode(data, (ACTION_TYPE, address));
        (, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 scyOwed = scyToAccount.neg().Uint();

        address[] memory receivers = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        (receivers[0], amounts[0]) = (market, scyOwed);
        (receivers[1], amounts[1]) = (receiver, type(uint256).max);

        YT.redeemPY(receivers, amounts);
    }

    function _swapPtForYt_callback(
        address market,
        int256, /**ptToAccount */
        int256, /**scyToAccount */
        bytes calldata data
    ) internal {
        (, address receiver) = abi.decode(data, (ACTION_TYPE, address));
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        YT.mintPY(market, receiver);
    }

    function _swapYtForPt_callback(
        address market,
        int256 ptToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        (, address receiver) = abi.decode(data, (ACTION_TYPE, address));
        (ISuperComposableYield SCY, IERC20 PT, IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 scyIndex = SCY.exchangeRateCurrent();
        uint256 scyOwed = scyToAccount.neg().Uint();
        uint256 assetOwed = SCYUtils.scyToAsset(scyIndex, scyOwed);

        PT.safeTransfer(address(YT), assetOwed);
        PT.safeTransfer(receiver, ptToAccount.Uint() - assetOwed);
        YT.redeemPY(market);
    }
}
