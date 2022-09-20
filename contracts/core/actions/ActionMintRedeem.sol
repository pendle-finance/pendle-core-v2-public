// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./base/ActionBaseMintRedeem.sol";
import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPActionMintRedeem.sol";

contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {
    using MarketMathCore for MarketState;
    using Math for uint256;
    using Math for int256;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter)
        ActionBaseMintRedeem(_kyberSwapRouter) //solhint-disable-next-line no-empty-blocks
    {}

    /// @dev refer to the internal function
    function mintScyFromToken(
        address receiver,
        address SCY,
        uint256 minScyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netScyOut) {
        netScyOut = _mintScyFromToken(receiver, SCY, minScyOut, input);

        emit MintScyFromToken(
            msg.sender,
            receiver,
            SCY,
            input.tokenIn,
            input.netTokenIn,
            netScyOut
        );
    }

    /// @dev refer to the internal function
    function redeemScyToToken(
        address receiver,
        address SCY,
        uint256 netScyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut) {
        netTokenOut = _redeemScyToToken(receiver, SCY, netScyIn, output, true);
        emit RedeemScyToToken(msg.sender, receiver, SCY, netScyIn, output.tokenOut, netTokenOut);
    }

    /// @dev refer to the internal function
    function mintPyFromToken(
        address receiver,
        address YT,
        uint256 minPyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netPyOut) {
        netPyOut = _mintPyFromToken(receiver, YT, minPyOut, input);
        emit MintPyFromToken(msg.sender, receiver, YT, input.tokenIn, input.netTokenIn, netPyOut);
    }

    /// @dev refer to the internal function
    function redeemPyToToken(
        address receiver,
        address YT,
        uint256 netPyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut) {
        netTokenOut = _redeemPyToToken(receiver, YT, netPyIn, output, true);
        emit RedeemPyToToken(msg.sender, receiver, YT, netPyIn, output.tokenOut, netTokenOut);
    }

    function mintPyFromScy(
        address receiver,
        address YT,
        uint256 netScyIn,
        uint256 minPyOut
    ) external returns (uint256 netPyOut) {
        netPyOut = _mintPyFromScy(receiver, YT, netScyIn, minPyOut, true);
        emit MintPyFromScy(msg.sender, receiver, YT, netScyIn, netPyOut);
    }

    function redeemPyToScy(
        address receiver,
        address YT,
        uint256 netPyIn,
        uint256 minScyOut
    ) external returns (uint256 netScyOut) {
        netScyOut = _redeemPyToScy(receiver, YT, netPyIn, minScyOut, true);
        emit RedeemPyToScy(msg.sender, receiver, YT, netPyIn, netScyOut);
    }

    function redeemDueInterestAndRewards(
        address user,
        address[] calldata scys,
        address[] calldata yts,
        address[] calldata markets
    )
        external
        returns (
            uint256[][] memory scyRewards,
            uint256[] memory ytInterests,
            uint256[][] memory ytRewards,
            uint256[][] memory marketRewards
        )
    {
        scyRewards = new uint256[][](scys.length);
        for (uint256 i = 0; i < scys.length; ++i) {
            scyRewards[i] = ISuperComposableYield(scys[i]).claimRewards(user);
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
            scys,
            yts,
            markets,
            scyRewards,
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
        address[] calldata scys,
        RouterYtRedeemStruct calldata dataYT,
        address[] calldata markets,
        RouterSwapAllStruct calldata dataSwap
    ) external returns (uint256 netTokenOut, uint256[] memory amountsSwapped) {
        require(dataSwap.tokens.length == dataSwap.kybercalls.length, "invalid dataSwap");
        require(dataYT.tokenRedeemScys.length == dataYT.scyAddrs.length, "invalid dataYT");

        RouterTokenAmounts memory tokensOut = _newRouterTokenAmounts(dataSwap.tokens);
        RouterTokenAmounts memory scysOut = _newRouterTokenAmounts(dataYT.scyAddrs);

        // redeem SCY
        for (uint256 i = 0; i < scys.length; ++i) {
            ISuperComposableYield SCY = ISuperComposableYield(scys[i]);

            address[] memory rewardTokens = SCY.getRewardTokens();
            uint256[] memory rewardAmounts = SCY.claimRewards(msg.sender);
            _addTokenAmounts(tokensOut, rewardTokens, rewardAmounts);
        }

        // redeem YT
        for (uint256 i = 0; i < dataYT.yts.length; ++i) {
            IPYieldToken YT = IPYieldToken(dataYT.yts[i]);

            (uint256 interestAmount, uint256[] memory rewardAmounts) = YT
                .redeemDueInterestAndRewards(msg.sender, true, true);

            address scyAddr = YT.SCY();
            address[] memory rewardTokens = YT.getRewardTokens();

            _addTokenAmount(scysOut, scyAddr, interestAmount);
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
        _transferFrom(tokensOut.tokens, msg.sender, address(this), tokensOut.amounts);
        _redeemAllScys(scysOut, dataYT.tokenRedeemScys, tokensOut);

        // now swap all to outputToken
        netTokenOut = _swapAllToOutputToken(tokensOut, dataSwap);
        amountsSwapped = tokensOut.amounts;

        emit RedeemDueInterestAndRewardsThenSwapAll(
            msg.sender,
            scys,
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

    /// @dev pull SCYs from users & redeem them, then add to tokensOut
    function _redeemAllScys(
        RouterTokenAmounts memory scys,
        address[] calldata tokenRedeemScys,
        RouterTokenAmounts memory tokensOut
    ) internal {
        for (uint256 i = 0; i < scys.tokens.length; ++i) {
            if (scys.amounts[i] == 0) continue;

            _transferFrom(scys.tokens[i], msg.sender, scys.tokens[i], scys.amounts[i]);
            uint256 amountOut = ISuperComposableYield(scys.tokens[i]).redeem(
                address(this),
                scys.amounts[i],
                tokenRedeemScys[i],
                1,
                true
            );

            _addTokenAmount(tokensOut, tokenRedeemScys[i], amountOut);
        }
    }

    function _swapAllToOutputToken(
        RouterTokenAmounts memory tokens,
        RouterSwapAllStruct memory dataSwap
    ) internal returns (uint256 netTokenOut) {
        for (uint256 i = 0; i < tokens.tokens.length; ++i) {
            if (tokens.amounts[i] == 0) continue;
            _kyberswap(tokens.tokens[i], tokens.amounts[i], dataSwap.kybercalls[i]);
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
