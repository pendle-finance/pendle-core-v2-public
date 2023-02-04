// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../SYBaseWithRewards.sol";
import "./GMXPreviewHelper.sol";
import "../../../../interfaces/GMX/IRewardRouterV2.sol";
import "../../../../interfaces/GMX/IGlpManager.sol";
import "../../../../interfaces/GMX/IGMXVault.sol";

contract PendleGlpSY is SYBaseWithRewards, GMXPreviewHelper {
    address public immutable glp;
    address public immutable stakedGlp;
    address public immutable rewardRouter;
    address public immutable glpRewardRouter;
    address public immutable glpManager;
    address public immutable weth;

    constructor(
        string memory _name,
        string memory _symbol,
        address _glp,
        address _fsGlp,
        address _stakedGlp,
        address _rewardRouter,
        address _glpRewardRouter,
        address _vault
    ) SYBaseWithRewards(_name, _symbol, _fsGlp) GMXPreviewHelper(_vault) {
        glp = _glp;
        stakedGlp = _stakedGlp;
        rewardRouter = _rewardRouter;
        glpRewardRouter = _glpRewardRouter;
        glpManager = IRewardRouterV2(glpRewardRouter).glpManager();
        weth = IRewardRouterV2(glpRewardRouter).weth();

        uint256 length = vault.allWhitelistedTokensLength();
        for (uint256 i = 0; i < length; ++i) {
            _safeApproveInf(vault.allWhitelistedTokens(i), glpManager);
        }
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {SYBase-_deposit}
     */
    function _deposit(address tokenIn, uint256 amountDeposited)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == stakedGlp) {
            // GLP is already staked in stakedGlp's transferFrom, called in _transferIn()
            amountSharesOut = amountDeposited;
        } else if (tokenIn == NATIVE) {
            amountSharesOut = IRewardRouterV2(glpRewardRouter).mintAndStakeGlpETH{
                value: msg.value
            }(0, 0);
        } else {
            amountSharesOut = IRewardRouterV2(glpRewardRouter).mintAndStakeGlp(
                tokenIn,
                amountDeposited,
                0,
                0
            );
        }
    }

    /**
     * @dev See {SYBase-_redeem}
     */
    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        if (tokenOut == stakedGlp) {
            amountTokenOut = amountSharesToRedeem;
            _transferOut(tokenOut, receiver, amountTokenOut);
        } else if (tokenOut == NATIVE) {
            amountTokenOut = IRewardRouterV2(glpRewardRouter).unstakeAndRedeemGlpETH(
                amountSharesToRedeem,
                0,
                payable(receiver)
            );
        } else {
            amountTokenOut = IRewardRouterV2(glpRewardRouter).unstakeAndRedeemGlp(
                tokenOut,
                amountSharesToRedeem,
                0,
                receiver
            );
        }
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates and updates the exchange rate of shares to underlying asset token
     * @dev 1 SY = 1 GLP
     */
    function exchangeRate() public view virtual override returns (uint256) {
        return Math.ONE;
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {IStandardizedYield-getRewardTokens}
     */
    function _getRewardTokens() internal view override returns (address[] memory res) {
        res = new address[](1);
        res[0] = weth;
    }

    function _redeemExternalReward() internal override {
        IRewardRouterV2(rewardRouter).claim();
    }

    /*///////////////////////////////////////////////////////////////
                    MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == stakedGlp) amountSharesOut = amountTokenToDeposit;
        else {
            if (tokenIn == NATIVE) tokenIn = weth;

            // Based on GlpManager's _addLiquidity
            uint256 aumInUsdg = IGlpManager(glpManager).getAumInUsdg(true);
            uint256 glpSupply = IERC20(glp).totalSupply();
            uint256 usdgAmount = super.buyUSDG(tokenIn, amountTokenToDeposit);

            uint256 mintAmount = aumInUsdg == 0
                ? usdgAmount
                : (usdgAmount * glpSupply) / aumInUsdg;
            amountSharesOut = mintAmount;
        }
    }

    function _previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        view
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == stakedGlp) amountTokenOut = amountSharesToRedeem;
        else {
            if (tokenOut == NATIVE) tokenOut = weth;

            // Based on GlpManager's _removeLiquidity
            uint256 aumInUsdg = IGlpManager(glpManager).getAumInUsdg(false);
            uint256 glpSupply = IERC20(glp).totalSupply();

            uint256 usdgAmount = (amountSharesToRedeem * aumInUsdg) / glpSupply;
            uint256 amountOut = super.sellUSDG(tokenOut, usdgAmount);

            amountTokenOut = amountOut;
        }
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](vault.whitelistedTokenCount() + 2);
        res[0] = stakedGlp;
        res[1] = NATIVE;

        uint256 resIndex = 2;
        uint256 length = vault.allWhitelistedTokensLength();
        for (uint256 i = 0; i < length; ) {
            address token = vault.allWhitelistedTokens(i);
            if (vault.whitelistedTokens(token)) {
                res[resIndex] = token;
                unchecked {
                    ++resIndex;
                }
            }
            unchecked {
                ++i;
            }
        }
        require(resIndex == res.length, "Wrong whitelisted tokens count");
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](vault.whitelistedTokenCount() + 2);
        res[0] = stakedGlp;
        res[1] = NATIVE;

        uint256 resIndex = 2;
        uint256 length = vault.allWhitelistedTokensLength();
        for (uint256 i = 0; i < length; ) {
            address token = vault.allWhitelistedTokens(i);
            if (vault.whitelistedTokens(token)) {
                res[resIndex] = token;
                unchecked {
                    ++resIndex;
                }
            }
            unchecked {
                ++i;
            }
        }
        require(resIndex == res.length, "Wrong whitelisted tokens count");
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == stakedGlp || token == NATIVE || vault.whitelistedTokens(token);
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == stakedGlp || token == NATIVE || vault.whitelistedTokens(token);
    }

    function assetInfo()
        external
        view
        returns (
            AssetType assetType,
            address assetAddress,
            uint8 assetDecimals
        )
    {
        return (AssetType.LIQUIDITY, glp, IERC20Metadata(glp).decimals());
    }
}
