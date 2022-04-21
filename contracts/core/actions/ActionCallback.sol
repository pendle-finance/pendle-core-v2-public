// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPMarketAddRemoveCallback.sol";
import "../../interfaces/IPMarketSwapCallback.sol";
import "../../SuperComposableYield/SCYUtils.sol";
import "../../libraries/math/MarketApproxLib.sol";
import "../../libraries/math/MarketMathAux.sol";
import "./base/ActionSCYAndYOBase.sol";
import "./base/ActionType.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ActionCallback is IPMarketSwapCallback, ActionType {
    address public immutable marketFactory;
    using Math for int256;
    using Math for uint256;
    using SafeERC20 for ISuperComposableYield;
    using SafeERC20 for IPYieldToken;

    modifier onlyPendleMarket(address market) {
        require(IPMarketFactory(marketFactory).isValidMarket(market), "INVALID_MARKET");
        _;
    }

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _marketFactory) {
        require(_marketFactory != address(0), "zero address");
        marketFactory = _marketFactory;
    }

    function swapCallback(
        int256 otToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) external override onlyPendleMarket(msg.sender) {
        (ACTION_TYPE swapType, ) = abi.decode(data, (ACTION_TYPE, address));
        if (swapType == ACTION_TYPE.SwapExactScyForYt) {
            _swapExactScyForYt_callback(msg.sender, otToAccount, scyToAccount, data);
        } else if (swapType == ACTION_TYPE.SwapSCYForExactYt) {
            _swapScyForExactYt_callback(msg.sender, otToAccount, scyToAccount, data);
        } else if (
            swapType == ACTION_TYPE.SwapYtForExactScy || swapType == ACTION_TYPE.SwapExactYtForScy
        ) {
            _swapYtForScy_callback(msg.sender, otToAccount, scyToAccount, data);
        } else {
            require(false, "unknown swapType");
        }
    }

    function _swapExactScyForYt_callback(
        address market,
        int256 otToAccount,
        int256, /*scyToAccount*/
        bytes calldata data
    ) internal {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        (, address receiver) = abi.decode(data, (ACTION_TYPE, address));

        uint256 otOwed = otToAccount.abs();
        uint256 amountYOout = YT.mintYO(market, receiver);

        require(amountYOout >= otOwed, "insufficient ot to pay");
    }

    function _swapScyForExactYt_callback(
        address market,
        int256 otToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        (, address payer, address receiver) = abi.decode(data, (ACTION_TYPE, address, address));
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 otOwed = otToAccount.neg().Uint();
        uint256 scyReceived = scyToAccount.Uint();

        // otOwed = totalAsset
        uint256 scyIndex = SCY.scyIndexCurrent();
        uint256 scyNeedTotal = SCYUtils.assetToScy(scyIndex, otOwed);
        scyNeedTotal += scyIndex.rawDivUp(SCYUtils.ONE);

        {
            uint256 netScyToPull = scyNeedTotal.subMax0(scyReceived);
            SCY.safeTransferFrom(payer, address(YT), netScyToPull);
        }

        uint256 amountYOout = YT.mintYO(market, receiver);

        require(amountYOout >= otOwed, "insufficient ot to pay");
    }

    /**
    @dev receive PT -> pair with YT to redeem SCY -> payback SCY
    */
    function _swapYtForScy_callback(
        address market,
        int256, /*otToAccount*/
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        (, address receiver) = abi.decode(data, (ACTION_TYPE, address));
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 scyOwed = scyToAccount.neg().Uint();

        uint256 netScyReceived = YT.redeemYO(address(this));

        SCY.safeTransfer(market, scyOwed);

        if (receiver != address(this)) {
            SCY.safeTransfer(receiver, netScyReceived - scyOwed);
        }
    }
}
