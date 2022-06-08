// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPMarketAddRemoveCallback.sol";
import "../../interfaces/IPMarketSwapCallback.sol";
import "../../libraries/SCYUtils.sol";
import "../../libraries/math/MarketApproxLib.sol";
import "./base/ActionSCYAndPYBase.sol";
import "./base/CallbackHelper.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ActionCallback is IPMarketSwapCallback, CallbackHelper {
    using Math for int256;
    using Math for uint256;
    using SafeERC20 for ISuperComposableYield;
    using SafeERC20 for IPYieldToken;
    using SafeERC20 for IERC20;
    using SCYIndexLib for SCYIndex;
    using SCYIndexLib for ISuperComposableYield;

    address public immutable marketFactory;

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
        address market = msg.sender;
        ActionType swapType = _getActionType(data);
        if (swapType == ActionType.SwapExactScyForYt) {
            _callbackSwapExactScyForYt(market, ptToAccount, scyToAccount, data);
        } else if (swapType == ActionType.SwapScyForExactYt) {
            _callbackSwapScyForExactYt(market, ptToAccount, scyToAccount, data);
        } else if (swapType == ActionType.SwapYtForScy) {
            _callbackSwapYtForScy(market, ptToAccount, scyToAccount, data);
        } else {
            require(false, "unknown swapType");
        }
    }

    /// @dev refer to _swapExactScyForYt
    function _callbackSwapExactScyForYt(
        address market,
        int256 ptToAccount,
        int256, /*scyToAccount*/
        bytes calldata data
    ) internal {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        (address receiver, uint256 minYtOut) = _decodeSwapExactScyForYt(data);

        uint256 ptOwed = ptToAccount.abs();
        uint256 amountPYout = YT.mintPY(market, receiver);

        require(amountPYout >= ptOwed, "insufficient PT to pay");
        require(amountPYout >= minYtOut, "insufficient YT out");
    }

    struct VarsSwapScyForExactYt {
        address payer;
        address receiver;
        uint256 maxScyToPull;
    }

    /// @dev refer to _swapScyForExactYt
    function _callbackSwapScyForExactYt(
        address market,
        int256 ptToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        VarsSwapScyForExactYt memory vars;
        (vars.payer, vars.receiver, vars.maxScyToPull) = _decodeSwapScyForExactYt(data);
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        /// ------------------------------------------------------------
        /// calc totalScyNeed
        /// ------------------------------------------------------------
        SCYIndex scyIndex = SCY.newIndex();
        uint256 ptOwed = ptToAccount.abs();
        uint256 totalScyNeed = scyIndex.assetToScy(ptOwed);
        // to guard against precision issue of lacking a few units of SCY. rawDivUp is not Fixed-Point division
        totalScyNeed += SCYIndex.unwrap(scyIndex).rawDivUp(SCYUtils.ONE);

        /// ------------------------------------------------------------
        /// calc netScyToPull
        /// ------------------------------------------------------------
        uint256 scyReceived = scyToAccount.Uint();
        uint256 netScyToPull = totalScyNeed.subMax0(scyReceived);
        require(netScyToPull <= vars.maxScyToPull, "exceed SCY in limit");

        /// ------------------------------------------------------------
        /// mint & transfer
        /// ------------------------------------------------------------
        SCY.safeTransferFrom(vars.payer, address(YT), netScyToPull);

        uint256 amountPYout = YT.mintPY(market, vars.receiver);
        require(amountPYout >= ptOwed, "insufficient pt to pay");
    }

    /// @dev refer to _swapExactYtForScy or _swapYtForExactScy
    function _callbackSwapYtForScy(
        address market,
        int256, /*ptToAccount*/
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        (address receiver, uint256 minScyOut) = _decodeSwapYtForScy(data);
        (, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 scyOwed = scyToAccount.neg().Uint();

        address[] memory receivers = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        (receivers[0], amounts[0]) = (market, scyOwed);
        (receivers[1], amounts[1]) = (receiver, type(uint256).max);

        uint256 netScyOut = YT.redeemPY(receivers, amounts);
        require(netScyOut >= minScyOut, "insufficient SCY out");
    }
}
