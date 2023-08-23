// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./base/ActionBaseMintRedeem.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPActionMintRedeem.sol";
import "../core/libraries/Errors.sol";

contract ActionMintRedeem is IPActionMintRedeem, ActionBaseMintRedeem {
    using MarketMathCore for MarketState;
    using PMath for uint256;
    using PMath for int256;

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
}
