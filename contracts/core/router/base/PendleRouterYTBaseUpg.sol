// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../../interfaces/IPMarketFactory.sol";
import "../../../interfaces/IPMarket.sol";
import "../../../interfaces/IPMarketAddRemoveCallback.sol";
import "../../../interfaces/IPMarketSwapCallback.sol";
import "../../../SuperComposableYield/SCYUtils.sol";
import "../../../libraries/math/MarketApproxLib.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract PendleRouterYTBaseUpg is IPMarketSwapCallback {
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using MarketMathLib for MarketParameters;
    using MarketApproxLib for MarketParameters;
    using SafeERC20 for ISuperComposableYield;
    using SafeERC20 for IPYieldToken;

    // solhint-disable-next-line
    enum YT_SWAP_TYPE {
        ExactYtForScy,
        SCYForExactYt,
        ExactScyForYt
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

    function _swapExactScyForYt(
        address receiver,
        address market,
        uint256 exactScyIn,
        uint256 minYtOut,
        uint256 netYtOutGuessMin,
        uint256 netYtOutGuessMax,
        bool doPull
    ) internal returns (uint256 netYtOut) {
        {
            (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();
            {
                MarketParameters memory state = IPMarket(market).readState();

                netYtOut = state.approxSwapExactScyForYt(
                    SCYIndexLib.newIndex(SCY),
                    exactScyIn,
                    block.timestamp,
                    netYtOutGuessMin,
                    netYtOutGuessMax
                );
                require(netYtOut >= minYtOut, "insufficient out");
            }

            if (doPull) {
                SCY.safeTransferFrom(msg.sender, address(YT), exactScyIn);
            }
        }

        {
            uint256 exactOtIn = netYtOut;
            IPMarket(market).swapExactOtForScy(
                receiver,
                exactOtIn,
                1,
                abi.encode(YT_SWAP_TYPE.ExactScyForYt, receiver)
            );
        }
    }

    /**
    * @dev inner working of this function:
     - YT is transferred to the YT contract
     - market.swap is called, which will transfer OT directly to the YT contract, and callback is invoked
     - callback will call YT's redeemYO, which will redeem the outcome SCY to this router, then
        all SCY owed to the market will be paid, the rest is transferred to the receiver
     */
    function _swapExactYtForScy(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minScyOut,
        bool doPull
    ) internal returns (uint256 netScyOut) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        // takes out the same amount of OT as exactYtIn, to pair together
        uint256 exactOtOut = exactYtIn;

        uint256 preBalanceScy = SCY.balanceOf(receiver);

        if (doPull) {
            YT.safeTransferFrom(msg.sender, address(YT), exactYtIn);
        }

        IPMarket(market).swapScyForExactOt(
            receiver,
            exactOtOut,
            type(uint256).max,
            abi.encode(YT_SWAP_TYPE.ExactYtForScy, receiver)
        );

        netScyOut = SCY.balanceOf(receiver) - preBalanceScy;
        require(netScyOut >= minScyOut, "INSUFFICIENT_SCY_OUT");
    }

    /**
     * @dev inner working of this function:
     - market.swap is called, which will transfer SCY directly to the YT contract, and callback is invoked
     - callback will pull more SCY if necessary, do call YT's mintYO, which will mint OT to the market & YT to the receiver
     */
    function _swapScyForExactYt(
        address receiver,
        address market,
        uint256 exactYtOut,
        uint256 maxScyIn
    ) internal returns (uint256 netScyIn) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        uint256 exactOtIn = exactYtOut;
        uint256 preBalanceScy = SCY.balanceOf(receiver);

        IPMarket(market).swapExactOtForScy(
            receiver,
            exactOtIn,
            1,
            abi.encode(YT_SWAP_TYPE.SCYForExactYt, msg.sender, receiver)
        );

        netScyIn = preBalanceScy - SCY.balanceOf(receiver);

        require(netScyIn <= maxScyIn, "exceed out limit");
    }

    function swapCallback(
        int256 otToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) external override onlyPendleMarket(msg.sender) {
        (YT_SWAP_TYPE swapType, ) = abi.decode(data, (YT_SWAP_TYPE, bytes));

        if (swapType == YT_SWAP_TYPE.ExactScyForYt) {
            _swapExactScyForYt_callback(msg.sender, data);
        } else if (swapType == YT_SWAP_TYPE.ExactYtForScy) {
            _swapExactYtForScy_callback(msg.sender, scyToAccount, data);
        } else if (swapType == YT_SWAP_TYPE.SCYForExactYt) {
            _swapScyForExactYt_callback(msg.sender, otToAccount, scyToAccount, data);
        } else {
            require(false, "unknown swapType");
        }
    }

    function _swapExactScyForYt_callback(address market, bytes calldata data) internal {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        (, address receiver) = abi.decode(data, (YT_SWAP_TYPE, address));

        YT.mintYO(market, receiver);
    }

    function _swapScyForExactYt_callback(
        address market,
        int256 otToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        (, address payer, address receiver) = abi.decode(data, (YT_SWAP_TYPE, address, address));
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 otOwed = otToAccount.neg().Uint();
        uint256 scyReceived = scyToAccount.Uint();

        // otOwed = totalAsset
        uint256 scyNeedTotal = SCYUtils.assetToScy(SCY.scyIndexCurrent(), otOwed);

        uint256 netScyToPull = scyNeedTotal.subMax0(scyReceived);
        SCY.safeTransferFrom(payer, address(YT), netScyToPull);

        YT.mintYO(market, receiver);
    }

    /**
    @dev receive OT -> pair with YT to redeem SCY -> payback SCY
    */
    function _swapExactYtForScy_callback(
        address market,
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        (, address receiver) = abi.decode(data, (YT_SWAP_TYPE, address));
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 scyOwed = scyToAccount.neg().Uint();

        uint256 netScyReceived = YT.redeemYO(address(this));

        SCY.safeTransfer(market, scyOwed);

        if (receiver != address(this)) {
            SCY.safeTransfer(receiver, netScyReceived - scyOwed);
        }
    }
}
