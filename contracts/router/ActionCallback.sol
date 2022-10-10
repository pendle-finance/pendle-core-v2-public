// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../interfaces/IPMarketFactory.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPMarketSwapCallback.sol";
import "../core/libraries/Errors.sol";

import "./base/MarketApproxLib.sol";
import "./base/ActionBaseMintRedeem.sol";
import "./base/CallbackHelper.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ActionCallback is IPMarketSwapCallback, CallbackHelper {
    using Math for int256;
    using Math for uint256;
    using SafeERC20 for IStandardizedYield;
    using SafeERC20 for IPYieldToken;
    using SafeERC20 for IPPrincipalToken;
    using SafeERC20 for IERC20;
    using PYIndexLib for PYIndex;
    using PYIndexLib for IPYieldToken;

    address public immutable marketFactory;

    modifier onlyPendleMarket(address caller) {
        if (!IPMarketFactory(marketFactory).isValidMarket(caller))
            revert Errors.RouterCallbackNotPendleMarket(caller);
        _;
    }

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _marketFactory) {
        marketFactory = _marketFactory;
    }

    /**
     * @dev The callback is only callable by a Pendle Market created by the factory
     */
    function swapCallback(
        int256 ptToAccount,
        int256 syToAccount,
        bytes calldata data
    ) external override onlyPendleMarket(msg.sender) {
        address market = msg.sender;
        ActionType swapType = _getActionType(data);
        if (swapType == ActionType.SwapExactSyForYt) {
            _callbackSwapExactSyForYt(market, ptToAccount, syToAccount, data);
        } else if (swapType == ActionType.SwapSyForExactYt) {
            _callbackSwapSyForExactYt(market, ptToAccount, syToAccount, data);
        } else if (swapType == ActionType.SwapYtForSy) {
            _callbackSwapYtForSy(market, ptToAccount, syToAccount, data);
        } else if (swapType == ActionType.SwapExactYtForPt) {
            _callbackSwapExactYtForPt(market, ptToAccount, syToAccount, data);
        } else if (swapType == ActionType.SwapExactPtForYt) {
            _callbackSwapExactPtForYt(market, ptToAccount, syToAccount, data);
        } else {
            assert(false);
        }
    }

    /// @dev refer to _swapExactSyForYt
    function _callbackSwapExactSyForYt(
        address market,
        int256 ptToAccount,
        int256, /*syToAccount*/
        bytes calldata data
    ) internal {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        (address receiver, uint256 minYtOut) = _decodeSwapExactSyForYt(data);

        uint256 ptOwed = ptToAccount.abs();
        uint256 netPyOut = YT.mintPY(market, receiver);

        if (netPyOut < ptOwed) revert Errors.RouterInsufficientPtRepay(netPyOut, ptOwed);
        if (netPyOut < minYtOut) revert Errors.RouterInsufficientYtOut(netPyOut, minYtOut);
    }

    struct VarsSwapSyForExactYt {
        address payer;
        address receiver;
        uint256 maxSyToPull;
    }

    /// @dev refer to _swapSyForExactYt
    function _callbackSwapSyForExactYt(
        address market,
        int256 ptToAccount,
        int256 syToAccount,
        bytes calldata data
    ) internal {
        VarsSwapSyForExactYt memory vars;
        (vars.payer, vars.receiver, vars.maxSyToPull) = _decodeSwapSyForExactYt(data);
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        /// ------------------------------------------------------------
        /// calc totalSyNeed
        /// ------------------------------------------------------------
        PYIndex pyIndex = YT.newIndex();
        uint256 ptOwed = ptToAccount.abs();
        uint256 totalSyNeed = pyIndex.assetToSyUp(ptOwed);

        /// ------------------------------------------------------------
        /// calc netSyToPull
        /// ------------------------------------------------------------
        uint256 syReceived = syToAccount.Uint();
        uint256 netSyToPull = totalSyNeed.subMax0(syReceived);

        if (netSyToPull > vars.maxSyToPull)
            revert Errors.RouterExceededLimitSyIn(netSyToPull, vars.maxSyToPull);

        /// ------------------------------------------------------------
        /// mint & transfer
        /// ------------------------------------------------------------
        if (netSyToPull > 0) {
            SY.safeTransferFrom(vars.payer, address(YT), netSyToPull);
        }

        uint256 netPyOut = YT.mintPY(market, vars.receiver);
        if (netPyOut < ptOwed) revert Errors.RouterInsufficientPtRepay(netPyOut, ptOwed);
    }

    /// @dev refer to _swapExactYtForSy or _swapYtForExactSy
    function _callbackSwapYtForSy(
        address market,
        int256 ptToAccount,
        int256 syToAccount,
        bytes calldata data
    ) internal {
        (address receiver, uint256 minSyOut) = _decodeSwapYtForSy(data);
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        PYIndex pyIndex = YT.newIndex();

        uint256 syOwed = syToAccount.neg().Uint();

        address[] memory receivers = new address[](2);
        uint256[] memory amountPYToRedeems = new uint256[](2);

        (receivers[0], amountPYToRedeems[0]) = (market, pyIndex.syToAssetUp(syOwed));
        (receivers[1], amountPYToRedeems[1]) = (
            receiver,
            ptToAccount.Uint() - amountPYToRedeems[0]
        );

        uint256[] memory amountSyOuts = YT.redeemPYMulti(receivers, amountPYToRedeems);
        if (amountSyOuts[1] < minSyOut)
            revert Errors.RouterInsufficientSyOut(amountSyOuts[1], minSyOut);
    }

    function _callbackSwapExactPtForYt(
        address market,
        int256 ptToAccount,
        int256, /*syToAccount*/
        bytes calldata data
    ) internal {
        (address receiver, uint256 exactPtIn, uint256 minYtOut) = _decodeSwapExactPtForYt(data);
        uint256 netPtOwed = ptToAccount.abs();
        (, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 netPyOut = YT.mintPY(market, receiver);
        if (netPyOut < minYtOut) revert Errors.RouterInsufficientYtOut(netPyOut, minYtOut);
        if (exactPtIn + netPyOut < netPtOwed)
            revert Errors.RouterInsufficientPtRepay(exactPtIn + netPyOut, netPtOwed);
    }

    function _callbackSwapExactYtForPt(
        address market,
        int256 ptToAccount,
        int256 syToAccount,
        bytes calldata data
    ) internal {
        (address receiver, uint256 exactYtIn, uint256 minPtOut) = _decodeSwapExactYtForPt(data);
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 netSyOwed = syToAccount.abs();

        PT.safeTransfer(address(YT), exactYtIn);
        uint256 netSyToMarket = YT.redeemPY(market);

        if (netSyToMarket < netSyOwed)
            revert Errors.RouterInsufficientSyRepay(netSyToMarket, netSyOwed);

        uint256 netPtOut = ptToAccount.Uint() - exactYtIn;
        if (netPtOut < minPtOut) revert Errors.RouterInsufficientPtOut(netPtOut, minPtOut);

        PT.safeTransfer(receiver, netPtOut);
    }
}
