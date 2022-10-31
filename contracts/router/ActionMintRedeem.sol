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
    using SafeERC20 for IERC20;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberScalingLib, address _bulkSellerDirectory)
        ActionBaseMintRedeem(_kyberScalingLib, _bulkSellerDirectory) //solhint-disable-next-line no-empty-blocks
    {}

    function mintSyFromToken(
        address receiver,
        address SY,
        uint256 minSyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netSyOut) {
        netSyOut = _mintSyFromToken(receiver, SY, minSyOut, input);
        emit MintSyFromToken(msg.sender, receiver, SY, input.tokenIn, input.netTokenIn, netSyOut);
    }

    function redeemSyToToken(
        address receiver,
        address SY,
        uint256 netSyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut) {
        netTokenOut = _redeemSyToToken(receiver, SY, netSyIn, output, true);
        emit RedeemSyToToken(msg.sender, receiver, SY, netSyIn, output.tokenOut, netTokenOut);
    }

    function mintPyFromToken(
        address receiver,
        address YT,
        uint256 minPyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netPyOut) {
        address SY = IPYieldToken(YT).SY();

        uint256 netSyToMint = _mintSyFromToken(YT, SY, 0, input);
        netPyOut = _mintPyFromSy(receiver, YT, minPyOut, netSyToMint, false);

        emit MintPyFromToken(msg.sender, receiver, YT, input.tokenIn, input.netTokenIn, netPyOut);
    }

    function redeemPyToToken(
        address receiver,
        address YT,
        uint256 netPyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut) {
        address SY = IPYieldToken(YT).SY();

        uint256 netSyToRedeem = _redeemPyToSy(_syOrBulk(SY, output), YT, netPyIn, 1, true);
        netTokenOut = _redeemSyToToken(receiver, SY, netSyToRedeem, output, false);

        emit RedeemPyToToken(msg.sender, receiver, YT, netPyIn, output.tokenOut, netTokenOut);
    }

    function mintPyFromSy(
        address receiver,
        address YT,
        uint256 netSyIn,
        uint256 minPyOut
    ) external returns (uint256 netPyOut) {
        netPyOut = _mintPyFromSy(receiver, YT, netSyIn, minPyOut, true);
        emit MintPyFromSy(msg.sender, receiver, YT, netSyIn, netPyOut);
    }

    function redeemPyToSy(
        address receiver,
        address YT,
        uint256 netPyIn,
        uint256 minSyOut
    ) external returns (uint256 netSyOut) {
        netSyOut = _redeemPyToSy(receiver, YT, netPyIn, minSyOut, true);
        emit RedeemPyToSy(msg.sender, receiver, YT, netPyIn, netSyOut);
    }

    function redeemDueInterestAndRewards(
        address user,
        address[] calldata sys,
        address[] calldata yts,
        address[] calldata markets
    )
        external
        returns (
            uint256[][] memory syRewards,
            uint256[] memory ytInterests,
            uint256[][] memory ytRewards,
            uint256[][] memory marketRewards
        )
    {
        syRewards = new uint256[][](sys.length);
        for (uint256 i = 0; i < sys.length; ++i) {
            syRewards[i] = IStandardizedYield(sys[i]).claimRewards(user);
        }

        ytInterests = new uint256[](yts.length);
        ytRewards = new uint256[][](yts.length);
        for (uint256 i = 0; i < yts.length; ++i) {
            (ytInterests[i], ytRewards[i]) = IPYieldToken(yts[i]).redeemDueInterestAndRewards(
                user,
                true,
                true
            );
        }

        marketRewards = new uint256[][](markets.length);
        for (uint256 i = 0; i < markets.length; ++i) {
            marketRewards[i] = IPMarket(markets[i]).redeemRewards(user);
        }
        emit RedeemDueInterestAndRewards(
            user,
            sys,
            yts,
            markets,
            syRewards,
            ytInterests,
            ytRewards,
            marketRewards
        );
    }

    struct RouterTokenAmounts {
        address[] tokens;
        uint256[] amounts;
    }

    function redeemDueInterestAndRewardsThenSwapAll(
        address[] calldata sys,
        RouterYtRedeemStruct calldata dataYT,
        address[] calldata markets,
        RouterSwapAllStruct calldata dataSwap
    ) external returns (uint256 netTokenOut, uint256[] memory amountsSwapped) {
        if (dataSwap.tokens.length != dataSwap.kybercalls.length)
            revert Errors.ArrayLengthMismatch();

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
            IERC20(tokensOut.tokens[i]).safeTransferFrom(
                msg.sender,
                address(this),
                tokensOut.amounts[i]
            );
        }
        _redeemAllSys(sysOut, dataYT.useBulks, dataYT.tokenRedeemSys, tokensOut);

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
        bool[] calldata useBulks,
        address[] calldata tokenRedeemSys,
        RouterTokenAmounts memory tokensOut
    ) internal {
        for (uint256 i = 0; i < sys.tokens.length; ++i) {
            if (sys.amounts[i] == 0) continue;

            TokenOutput memory output = _wrapTokenOutput(tokenRedeemSys[i], 1, useBulks[i]);
            uint256 amountOut = _redeemSyToToken(
                address(this),
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
            _kyberswap(tokens.tokens[i], tokens.amounts[i], dataSwap.kyberRouter, dataSwap.kybercalls[i]);
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
