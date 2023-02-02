// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./base/ActionBaseMintRedeem.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPActionMintRedeem.sol";
import "../core/libraries/Errors.sol";

contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {
    using MarketMathCore for MarketState;
    using Math for uint256;
    using Math for int256;

    /**
     * @notice swaps input token for SY-mintable tokens (if needed), then mints SY from such
     * @param input data for input token, see {`./kyberswap/KyberSwapHelper.sol`}
     */
    function mintSyFromToken(
        address receiver,
        address SY,
        uint256 minSyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netSyOut) {
        netSyOut = _mintSyFromToken(receiver, SY, minSyOut, input);
        emit MintSyFromToken(msg.sender, input.tokenIn, SY, receiver, input.netTokenIn, netSyOut);
    }

    /**
     * @notice redeems SY for SY-mintable tokens, then (if needed) swaps resulting tokens for
     * desired output token through Kyberswap
     * @param output data for desired output token, see {`./kyberswap/KyberSwapHelper.sol`}
     */
    function redeemSyToToken(
        address receiver,
        address SY,
        uint256 netSyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut) {
        netTokenOut = _redeemSyToToken(receiver, SY, netSyIn, output, true);
        emit RedeemSyToToken(msg.sender, output.tokenOut, SY, receiver, netSyIn, netTokenOut);
    }

    /**
     * @notice mints PY from any input token
     * @dev swaps input token through Kyberswap to SY-mintable tokens first, then mints SY, finally
     * mints PY from SY
     * @param input data for input token, see {`./kyberswap/KyberSwapHelper.sol`}
     * @dev reverts if PY is expired
     */
    function mintPyFromToken(
        address receiver,
        address YT,
        uint256 minPyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netPyOut) {
        address SY = IPYieldToken(YT).SY();

        uint256 netSyToMint = _mintSyFromToken(YT, SY, 0, input);
        netPyOut = _mintPyFromSy(receiver, SY, YT, netSyToMint, minPyOut, false);

        emit MintPyFromToken(msg.sender, input.tokenIn, YT, receiver, input.netTokenIn, netPyOut);
    }

    /**
     * @notice redeems PY for token
     * @dev redeems PT(+YT) for SY first, then redeems SY, finally swaps resulting tokens to output
     * token through Kyberswap (if needed)
     * @param output data for desired output token, see {`./kyberswap/KyberSwapHelper.sol`}
     */
    function redeemPyToToken(
        address receiver,
        address YT,
        uint256 netPyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut) {
        address SY = IPYieldToken(YT).SY();

        uint256 netSyToRedeem = _redeemPyToSy(_syOrBulk(SY, output), YT, netPyIn, 1);
        netTokenOut = _redeemSyToToken(receiver, SY, netSyToRedeem, output, false);

        emit RedeemPyToToken(msg.sender, output.tokenOut, YT, receiver, netPyIn, netTokenOut);
    }

    /**
     * @notice mints PT+YT from input SY
     * @dev reverts if the PY pair is expired
     */
    function mintPyFromSy(
        address receiver,
        address YT,
        uint256 netSyIn,
        uint256 minPyOut
    ) external returns (uint256 netPyOut) {
        netPyOut = _mintPyFromSy(receiver, IPYieldToken(YT).SY(), YT, netSyIn, minPyOut, true);
        emit MintPyFromSy(msg.sender, receiver, YT, netSyIn, netPyOut);
    }

    /// @notice redeems PT(+YT) for its corresponding SY
    function redeemPyToSy(
        address receiver,
        address YT,
        uint256 netPyIn,
        uint256 minSyOut
    ) external returns (uint256 netSyOut) {
        netSyOut = _redeemPyToSy(receiver, YT, netPyIn, minSyOut);
        emit RedeemPyToSy(msg.sender, receiver, YT, netPyIn, netSyOut);
    }

    /**
     * @notice A unified interface for redeeming rewards and interests for any SYs,
     * YTs, and markets alike for `user`.
     * @dev returns arrays of amounts claimed for each asset.
     */
    function redeemDueInterestAndRewards(
        address user,
        address[] calldata sys,
        address[] calldata yts,
        address[] calldata markets
    ) external {
        unchecked {
            for (uint256 i = 0; i < sys.length; ++i) {
                IStandardizedYield(sys[i]).claimRewards(user);
            }

            for (uint256 i = 0; i < yts.length; ++i) {
                IPYieldToken(yts[i]).redeemDueInterestAndRewards(user, true, true);
            }

            for (uint256 i = 0; i < markets.length; ++i) {
                IPMarket(markets[i]).redeemRewards(user);
            }
        }
    }

    struct RouterTokenAmounts {
        address[] tokens;
        uint256[] amounts;
    }

    /**
     * @notice A function to:
        - Redeem all of caller's due interest and rewards in SYs, YTs, and markets
        - Redeem SYs themselves
        - Finally swaps all resulting tokens to `dataSwap.outputToken`
     * @return netTokenOut total token output amount, will not be lower than `dataSwap.minTokenOut`
     * @return amountsSwapped the amounts swapped for each token defined in `dataSwap.tokens`
     */
    function redeemDueInterestAndRewardsThenSwapAll(
        address[] calldata sys,
        RouterYtRedeemStruct calldata dataYT,
        address[] calldata markets,
        RouterSwapAllStruct calldata dataSwap
    ) external returns (uint256 netTokenOut, uint256[] memory amountsSwapped) {
        if (dataSwap.tokens.length != dataSwap.data.length) revert Errors.ArrayLengthMismatch();

        if (dataYT.tokenRedeemSys.length != dataYT.syAddrs.length)
            revert Errors.ArrayLengthMismatch();

        RouterTokenAmounts memory tokensOut = _newRouterTokenAmounts(dataSwap.tokens);
        RouterTokenAmounts memory sysOut = _newRouterTokenAmounts(dataYT.syAddrs);

        // redeem SY
        for (uint256 i = 0; i < sys.length; ++i) {
            IStandardizedYield SY = IStandardizedYield(sys[i]);

            address[] memory rewardTokens = SY.getRewardTokens();
            uint256[] memory rewardAmounts = SY.claimRewards(msg.sender);
            _addTokenAmounts(tokensOut, rewardTokens, rewardAmounts);
        }

        // redeem YT
        for (uint256 i = 0; i < dataYT.yts.length; ++i) {
            IPYieldToken YT = IPYieldToken(dataYT.yts[i]);

            (uint256 interestAmount, uint256[] memory rewardAmounts) = YT
                .redeemDueInterestAndRewards(msg.sender, true, true);

            address syAddr = YT.SY();
            address[] memory rewardTokens = YT.getRewardTokens();

            _addTokenAmount(sysOut, syAddr, interestAmount);
            _addTokenAmounts(tokensOut, rewardTokens, rewardAmounts);
        }

        // redeem market
        for (uint256 i = 0; i < markets.length; ++i) {
            IPMarket market = IPMarket(markets[i]);

            address[] memory rewardTokens = market.getRewardTokens();
            uint256[] memory rewardAmounts = market.redeemRewards(msg.sender);
            _addTokenAmounts(tokensOut, rewardTokens, rewardAmounts);
        }

        // guaranteed no ETH, all rewards are ERC20
        for (uint256 i = 0; i < tokensOut.tokens.length; ++i) {
            _transferFrom(
                IERC20(tokensOut.tokens[i]),
                msg.sender,
                dataSwap.pendleSwap,
                tokensOut.amounts[i]
            );
        }
        _redeemAllSys(sysOut, dataYT.bulks, dataYT.tokenRedeemSys, tokensOut, dataSwap.pendleSwap);

        // now swap all to outputToken
        netTokenOut = _swapAllToOutputToken(tokensOut, dataSwap);

        if (netTokenOut < dataSwap.minTokenOut)
            revert Errors.RouterInsufficientTokenOut(netTokenOut, dataSwap.minTokenOut);

        amountsSwapped = tokensOut.amounts;

        emit RedeemDueInterestAndRewardsThenSwapAll(
            msg.sender,
            sys,
            dataYT.yts,
            markets,
            dataSwap.outputToken,
            netTokenOut
        );
    }

    function _newRouterTokenAmounts(address[] memory tokens)
        internal
        pure
        returns (RouterTokenAmounts memory)
    {
        return RouterTokenAmounts(tokens, new uint256[](tokens.length));
    }

    /// @dev pull SYs from users & redeem them, then add to tokensOut
    function _redeemAllSys(
        RouterTokenAmounts memory sys,
        address[] calldata bulks,
        address[] calldata tokenRedeemSys,
        RouterTokenAmounts memory tokensOut,
        address pendleSwap
    ) internal {
        for (uint256 i = 0; i < sys.tokens.length; ++i) {
            if (sys.amounts[i] == 0) continue;

            TokenOutput memory output = _wrapTokenOutput(tokenRedeemSys[i], 1, bulks[i]);
            uint256 amountOut = _redeemSyToToken(
                pendleSwap,
                sys.tokens[i],
                sys.amounts[i],
                output,
                true
            );

            _addTokenAmount(tokensOut, tokenRedeemSys[i], amountOut);
        }
    }

    function _swapAllToOutputToken(
        RouterTokenAmounts memory tokens,
        RouterSwapAllStruct memory dataSwap
    ) internal returns (uint256 netTokenOut) {
        for (uint256 i = 0; i < tokens.tokens.length; ++i) {
            if (tokens.amounts[i] == 0) continue;
            IPSwapAggregator(dataSwap.pendleSwap).swap(
                tokens.tokens[i],
                tokens.amounts[i],
                true,
                dataSwap.data[i]
            );
        }
        netTokenOut = _selfBalance(dataSwap.outputToken);
        _transferOut(dataSwap.outputToken, msg.sender, netTokenOut);
    }

    function _addTokenAmount(
        RouterTokenAmounts memory data,
        address token,
        uint256 amount
    ) internal pure {
        for (uint256 j = 0; j < data.tokens.length; j++) {
            if (data.tokens[j] == token) {
                data.amounts[j] += amount;
                return;
            }
        }
        revert("token not found");
    }

    function _addTokenAmounts(
        RouterTokenAmounts memory data,
        address[] memory tokens,
        uint256[] memory amounts
    ) internal pure {
        for (uint256 i = 0; i < tokens.length; i++) {
            _addTokenAmount(data, tokens[i], amounts[i]);
        }
    }
}
