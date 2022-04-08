// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../../interfaces/IPMarketFactory.sol";
import "../../../interfaces/IPMarket.sol";
import "../../../interfaces/IPMarketAddRemoveCallback.sol";
import "../../../interfaces/IPMarketSwapCallback.sol";
import "../../../SuperComposableYield/implementations/SCYUtils.sol";

abstract contract PendleRouterYTBaseUpg is IPMarketSwapCallback {
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using MarketMathLib for MarketParameters;

    // solhint-disable-next-line
    enum YT_SWAP_TYPE {
        ExactYtForSCY,
        SCYForExactYt,
        ExactSCYForYt
    }

    address public immutable marketFactory;

    modifier onlyPendleMarket(address market) {
        require(IPMarketFactory(marketFactory).isValidMarket(market), "INVALID_MARKET");
        _;
    }

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(
        address _marketFactory //solhint-disable-next-line no-empty-blocks
    ) {
        marketFactory = _marketFactory;
    }

    function _swapExactSCYForYt(
        address recipient,
        address market,
        uint256 exactSCYIn,
        uint256 minYtOut,
        uint256 netYtOutGuessMin,
        uint256 netYtOutGuessMax,
        bool doPull
    ) internal returns (uint256 netYtOut) {
        {
            MarketParameters memory state = IPMarket(market).readState();

            netYtOut = state.approxSwapExactSCYForYt(
                exactSCYIn,
                state.getTimeToExpiry(),
                netYtOutGuessMin,
                netYtOutGuessMax
            );
            require(netYtOut >= minYtOut, "insufficient out");
        }

        {
            (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

            if (doPull) {
                SCY.transferFrom(msg.sender, address(YT), exactSCYIn);
            }
        }

        {
            uint256 exactOtIn = netYtOut;
            // TODO: the 1 below can be better enforced?
            IPMarket(market).swapExactOtForSCY(
                recipient,
                exactOtIn,
                1,
                abi.encode(YT_SWAP_TYPE.ExactSCYForYt, recipient)
            );
        }
    }

    /**
    * @dev inner working of this function:
     - YT is transferred to the YT contract
     - market.swap is called, which will transfer OT directly to the YT contract, and callback is invoked
     - callback will call YT's redeemYO, which will redeem the outcome SCY to this router, then
        all SCY owed to the market will be paid, the rest is transferred to the recipient
     */
    function _swapExactYtForSCY(
        address recipient,
        address market,
        uint256 exactYtIn,
        uint256 minSCYOut,
        bool doPull
    ) internal returns (uint256 netSCYOut) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        // takes out the same amount of OT as exactYtIn, to pair together
        uint256 exactOtOut = exactYtIn;

        uint256 preBalanceSCY = SCY.balanceOf(recipient);

        if (doPull) {
            YT.transferFrom(msg.sender, address(YT), exactYtIn);
        }

        // because of SCY / YO conversion, the number may not be 100% accurate. TODO: find a better way
        IPMarket(market).swapSCYForExactOt(
            recipient,
            exactOtOut,
            type(uint256).max,
            abi.encode(YT_SWAP_TYPE.ExactYtForSCY, recipient)
        );

        netSCYOut = SCY.balanceOf(recipient) - preBalanceSCY;
        require(netSCYOut >= minSCYOut, "INSUFFICIENT_SCY_OUT");
    }

    /**
     * @dev inner working of this function:
     - market.swap is called, which will transfer SCY directly to the YT contract, and callback is invoked
     - callback will pull more SCY if necessary, do call YT's mintYO, which will mint OT to the market & YT to the recipient
     */
    function _swapSCYForExactYt(
        address recipient,
        address market,
        uint256 exactYtOut,
        uint256 maxSCYIn
    ) internal returns (uint256 netSCYIn) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        uint256 exactOtIn = exactYtOut;
        uint256 preBalanceSCY = SCY.balanceOf(recipient);

        IPMarket(market).swapExactOtForSCY(
            recipient,
            exactOtIn,
            1,
            abi.encode(YT_SWAP_TYPE.SCYForExactYt, msg.sender, recipient)
        );

        netSCYIn = preBalanceSCY - SCY.balanceOf(recipient);

        require(netSCYIn <= maxSCYIn, "exceed out limit");
    }

    function swapCallback(
        int256 otToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) external override onlyPendleMarket(msg.sender) {
        (YT_SWAP_TYPE swapType, ) = abi.decode(data, (YT_SWAP_TYPE, bytes));

        if (swapType == YT_SWAP_TYPE.ExactSCYForYt) {
            _swapExactSCYForYt_callback(msg.sender, data);
        } else if (swapType == YT_SWAP_TYPE.ExactYtForSCY) {
            _swapExactYtForSCY_callback(msg.sender, scyToAccount, data);
        } else if (swapType == YT_SWAP_TYPE.SCYForExactYt) {
            _swapSCYForExactYt_callback(msg.sender, otToAccount, scyToAccount, data);
        } else {
            require(false, "unknown swapType");
        }
    }

    function _swapExactSCYForYt_callback(address market, bytes calldata data) internal {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        (, address recipient) = abi.decode(data, (YT_SWAP_TYPE, address));

        YT.mintYO(market, recipient);
    }

    function _swapSCYForExactYt_callback(
        address market,
        int256 otToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        (, address payer, address recipient) = abi.decode(data, (YT_SWAP_TYPE, address, address));
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 otOwed = otToAccount.neg().Uint();
        uint256 scyReceived = scyToAccount.Uint();

        // otOwed = totalAsset
        uint256 scyNeedTotal = SCYUtils.assetToSCY(SCY.scyIndexCurrent(), otOwed);

        uint256 netSCYToPull = scyNeedTotal.subMax0(scyReceived);
        SCY.transferFrom(payer, address(YT), netSCYToPull);

        YT.mintYO(market, recipient);
    }

    /**
    @dev receive OT -> pair with YT to redeem SCY -> payback SCY
    */
    function _swapExactYtForSCY_callback(
        address market,
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        (, address recipient) = abi.decode(data, (YT_SWAP_TYPE, address));
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 scyOwed = scyToAccount.neg().Uint();

        uint256 netSCYReceived = YT.redeemYO(address(this));

        SCY.transfer(market, scyOwed);

        if (recipient != address(this)) {
            SCY.transfer(recipient, netSCYReceived - scyOwed);
        }
    }
}
