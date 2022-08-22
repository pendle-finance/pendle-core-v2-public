// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./base/ActionBaseTokenSCY.sol";
import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPActionMintRedeem.sol";

contract ActionMintRedeem is IPActionMintRedeem, ActionBaseTokenSCY {
    using MarketMathCore for MarketState;
    using Math for uint256;
    using Math for int256;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter)
        ActionBaseTokenSCY(_kyberSwapRouter) //solhint-disable-next-line no-empty-blocks
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
    }
}
