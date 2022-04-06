// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./PendleRouterSCYAndForge.sol";
import "./PendleRouterOT.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../libraries/helpers/MarketHelper.sol";

contract PendleRouterRawTokenYT is
    PendleRouterSCYAndForge,
    PendleRouterMarketBase,
    IPMarketSwapCallback
{
    using MarketMathLib for MarketParameters;
    using FixedPoint for uint256;
    using FixedPoint for int256;

    constructor(
        address _joeRouter,
        address _joeFactory,
        address _marketFactory
    )
        PendleRouterSCYAndForge(_joeRouter, _joeFactory)
        PendleRouterMarketBase(_marketFactory)
    //solhint-disable-next-line no-empty-blocks
    {

    }

    /**
     * @dev netYtOutGuessMin & Max can be used in the same way as RawTokenOT
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
     * @dev inner working of this function:
     - mintSCYFromRawToken is invoked, except the YT contract will receive all the outcome SCY
     - market.swap is called, which will transfer SCY to the YT contract, and callback is invoked
     - callback will do call YT's mintYO, which will mint OT to the market & YT to the recipient
     */
    function swapExactRawTokenForYt(
        uint256 exactRawTokenIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minYtOut,
        uint256 netYtOutGuessMin,
        uint256 netYtOutGuessMax
    ) external returns (uint256 netYtOut) {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        {
            MarketParameters memory state = IPMarket(market).readState();
            uint256 netSCYUsedToBuyYT = mintSCYFromRawToken(
                exactRawTokenIn,
                address(_market.SCY),
                1,
                address(_market.YT),
                path,
                true
            );

            netYtOut = state.approxSwapExactSCYForYt(
                netSCYUsedToBuyYT,
                state.getTimeToExpiry(),
                netYtOutGuessMin,
                netYtOutGuessMax
            );
        }

        require(netYtOut >= minYtOut, "insufficient out");
        {
            uint256 exactOtIn = netYtOut;
            // TODO: the 1 below can be better enforced?
            IPMarket(market).swapExactOtForSCY(recipient, exactOtIn, 1, abi.encode(recipient));
        }
    }

    /**
     * @notice swap YT -> SCY -> baseToken -> rawToken
     * @notice the algorithm to swap will guarantee to swap all the YT available
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
     * @dev inner working of this function:
     - YT is transferred to the YT contract
     - market.swap is called, which will transfer OT directly to the YT contract, and callback is invoked
     - callback will do call YT's redeemYO, which will redeem the outcome SCY to this router, then
        all SCY owed to the market will be paid, the rest is used to feed redeemSCYToRawToken
     */
    function swapExactYtForRawToken(
        uint256 exactYtIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minRawTokenOut
    ) external returns (uint256 netRawTokenOut) {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        _market.YT.transferFrom(msg.sender, address(_market.YT), exactYtIn);
        uint256 exactOtOut = exactYtIn;

        address rawToken = path[path.length - 1];
        uint256 preBalanceRawToken = IERC20(rawToken).balanceOf(recipient);
        IPMarket(market).swapSCYForExactOt(
            recipient,
            exactOtOut,
            type(uint256).max,
            abi.encode(recipient, path)
        );

        netRawTokenOut = IERC20(rawToken).balanceOf(recipient) - preBalanceRawToken;

        require(netRawTokenOut >= minRawTokenOut, "insufficient out");
    }

    function swapCallback(
        int256,
        int256 scyToAccount,
        bytes calldata data
    ) external override onlyPendleMarket(msg.sender) {
        // make sure payer, recipient same as when encode
        if (scyToAccount > 0) {
            address recipient = abi.decode(data, (address));
            _swapExactRawTokenForYt_callback(msg.sender, recipient);
        } else {
            (address recipient, address[] memory path) = abi.decode(data, (address, address[]));
            _swapExactYtForRawToken_callback(
                msg.sender,
                recipient,
                scyToAccount.neg().Uint(),
                path
            );
        }
    }

    function _swapExactRawTokenForYt_callback(address market, address recipient) internal {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        _market.YT.mintYO(market, recipient);
    }

    function _swapExactYtForRawToken_callback(
        address market,
        address recipient,
        uint256 scyOwed,
        address[] memory path
    ) internal {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        uint256 netSCYReceived = _market.YT.redeemYO(address(this));

        _market.SCY.transfer(market, scyOwed);
        _market.SCY.transfer(address(_market.SCY), netSCYReceived - scyOwed);

        redeemSCYToRawToken(address(_market.SCY), 0, 1, recipient, path, false);
    }
}
