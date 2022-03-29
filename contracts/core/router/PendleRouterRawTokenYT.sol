// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./PendleRouterLytAndForge.sol";
import "./PendleRouterOT.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../libraries/helpers/MarketHelper.sol";

contract PendleRouterRawTokenYT is
    PendleRouterLytAndForge,
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
        PendleRouterLytAndForge(_joeRouter, _joeFactory)
        PendleRouterMarketBase(_marketFactory)
    //solhint-disable-next-line no-empty-blocks
    {

    }

    /**
     * @dev netYtOutGuessMin & Max can be used in the same way as RawTokenOT
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
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

        MarketParameters memory state = IPMarket(market).readState();

        uint256 netLytUsedToBuyYT = mintLytFromRawToken(
            exactRawTokenIn,
            address(_market.YT),
            1,
            market,
            path
        );

        netYtOut = state.getSwapExactLytForYt(
            netLytUsedToBuyYT,
            IPMarket(market).timeToExpiry(),
            netYtOutGuessMin,
            netYtOutGuessMax
        );

        require(netYtOut >= minYtOut, "insufficient out");

        int256 otToAccount = netYtOut.toInt().neg();
        IPMarket(market).swap(address(_market.YT), otToAccount, abi.encode(recipient));
    }

    /**
     * @notice swap YT -> LYT -> baseToken -> rawToken
     * @notice the algorithm to swap will guarantee to swap all the YT available
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
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
        int256 otToAccount = exactYtIn.toInt();

        address rawToken = path[path.length - 1];
        uint256 preBalanceRawToken = IERC20(rawToken).balanceOf(recipient);
        IPMarket(market).swap(address(_market.YT), otToAccount, abi.encode(recipient));

        netRawTokenOut = IERC20(rawToken).balanceOf(recipient) - preBalanceRawToken;

        require(netRawTokenOut >= minRawTokenOut, "insufficient out");
    }

    function swapCallback(
        int256,
        int256 lytToAccount,
        bytes calldata data
    ) external override onlyPendleMarket(msg.sender) {
        // make sure payer, recipient same as when encode
        address recipient = abi.decode(data, (address));
        if (lytToAccount > 0) {
            _swapExactRawTokenForYt_callback(msg.sender, recipient);
        } else {
            _swapExactYtForRawToken_callback(msg.sender, recipient, lytToAccount.neg().toUint());
        }
    }

    function _swapExactRawTokenForYt_callback(address market, address recipient) internal {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        _market.YT.mintYO(market, recipient);
    }

    function _swapExactYtForRawToken_callback(
        address market,
        address recipient,
        uint256 lytOwed
    ) internal {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        uint256 netLytReceived = _market.YT.redeemYO(address(this));

        _market.LYT.transfer(market, lytOwed);
        _market.LYT.transfer(recipient, netLytReceived - lytOwed);
    }
}
