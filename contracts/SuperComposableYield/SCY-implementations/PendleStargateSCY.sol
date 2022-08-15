// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;
import "../base-implementations/SCYBaseWithRewards.sol";
import "../../interfaces/IStargateRouter.sol";
import "../../interfaces/IStargatePool.sol";
import "../../interfaces/IStargateLPStaking.sol";

contract PendleStargateSCY is SCYBaseWithRewards {
    address public immutable stgRouter;
    uint16 public immutable stgRouterPoolId;

    address public immutable stgStakingLP;
    uint256 public immutable pid;

    address public immutable underlying;
    address public immutable stgPool;
    address public immutable stgToken;

    constructor(
        string memory _name,
        string memory _symbol,
        address _stgRouter,
        address _stgStakingLP,
        uint256 _pid,
        address _stgPool
    ) SCYBaseWithRewards(_name, _symbol, _stgPool) {
        stgRouter = _stgRouter;

        stgRouterPoolId = uint16(IStargatePool(_stgPool).poolId());

        stgStakingLP = _stgStakingLP;
        pid = _pid;

        stgPool = _stgPool;
        stgToken = IStargateLPStaking(_stgStakingLP).stargate();
        underlying = IStargatePool(stgPool).token();

        // verify _pid
        require(
            IStargateLPStaking(_stgStakingLP).poolInfo(_pid).lpToken == _stgPool,
            "invalid pid"
        );

        _safeApprove(underlying, _stgRouter, type(uint256).max);
        // There is not a need to approve LP for router since stargate uses direct burn
        // _safeApprove(stgPool, _stgRouter, type(uint256).max);
        _safeApprove(stgPool, _stgStakingLP, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {SCYBase-_deposit}
     *
     * The underlying yield token is stargateLP. If the base token deposited is underlying, the function addLiquidity
     * using stargateRouter first. Then the amount of LP out will be taken into calculation.
     *
     * The exchange rate of stargateLP to shares is 1:1
     */
    function _deposit(address tokenIn, uint256 amountDeposited)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == stgPool) {
            amountSharesOut = amountDeposited;
        } else {
            uint256 preBalanceStgPool = _selfBalance(stgPool);
            IStargateRouter(stgRouter).addLiquidity(
                stgRouterPoolId,
                amountDeposited,
                address(this)
            );
            amountSharesOut = _selfBalance(stgPool) - preBalanceStgPool;
        }
        IStargateLPStaking(stgStakingLP).deposit(pid, amountSharesOut);
    }

    /**
     * @dev See {SCYBase-_redeem}
     *
     * The staked tokens are firstly withdraw from staking
     *
     * The shares are redeemed into underlying using router if necessary.
     */
    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        IStargateLPStaking(stgStakingLP).withdraw(pid, amountSharesToRedeem);
        if (tokenOut == stgPool) {
            amountTokenOut = amountSharesToRedeem;
        } else {
            uint256 preBalanceStgLp = IERC20(stgPool).balanceOf(address(this));
            amountTokenOut = IStargateRouter(stgRouter).instantRedeemLocal(
                stgRouterPoolId,
                amountSharesToRedeem,
                address(this)
            );

            uint256 amountLpUsed = preBalanceStgLp - IERC20(stgPool).balanceOf(address(this));

            // Since stargate is a bridge, sometime there might not be enough fund in the pool to redeem
            // In this case, stargate contract doesn't revert
            require(amountLpUsed == amountSharesToRedeem, "insufficient fund to redeem");
        }
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates and updates the exchange rate of shares to underlying asset token
     * @dev It is the exchange rate of stgPool to underlying
     */
    function exchangeRate() public view virtual override returns (uint256 currentRate) {
        return IStargatePool(stgPool).amountLPtoLD(SCYUtils.ONE);
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = stgPool;
        res[1] = underlying;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = stgPool;
        res[1] = underlying;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == stgPool || token == underlying;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == stgPool || token == underlying;
    }

    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == stgPool) amountSharesOut = amountTokenToDeposit;
        else amountSharesOut = (amountTokenToDeposit * SCYUtils.ONE) / exchangeRate();
    }

    function _previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        view
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == stgPool) amountTokenOut = amountSharesToRedeem;
        else amountTokenOut = (amountSharesToRedeem * exchangeRate()) / SCYUtils.ONE;
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
        return (AssetType.TOKEN, stgPool, IERC20Metadata(stgPool).decimals());
    }

    function _redeemExternalReward() internal override {
        IStargateLPStaking(stgStakingLP).withdraw(pid, 0);
    }

    /**
     * @dev See {ISuperComposableYield-getRewardTokens}
     */
    function _getRewardTokens() internal view override returns (address[] memory res) {
        res = new address[](1);
        res[0] = stgToken;
    }
}
