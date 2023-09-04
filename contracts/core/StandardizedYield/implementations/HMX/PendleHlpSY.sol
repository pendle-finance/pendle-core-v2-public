// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../SYBaseWithRewards.sol";

interface IHMXCompounder {
    function compound(
        address[] memory pools,
        address[][] memory rewarders,
        uint256 startEpochTimestamp,
        uint256 noOfEpochs,
        uint256[] calldata tokenIds
    ) external;
}

contract PendleHlpSY is SYBaseWithRewards {
    address public immutable hlp;
    address public immutable usdc;
    address public immutable compounder;

    address public immutable hmxStakingPool;
    address public immutable hlpStakingPool;

    address public immutable hlpUsdcRewarder;
    address public immutable hlpEsHmxRewarder;
    address public immutable hmxUsdcRewarder;

    constructor(
        string memory _name,
        string memory _symbol,
        address _hlp,
        address _usdc,
        address _compounder,
        address _hmxStakingPool,
        address _hlpStakingPool,
        address _hlpUsdcRewarder,
        address _hlpEsHmxRewarder,
        address _hmxUsdcRewarder
    ) SYBaseWithRewards(_name, _symbol, _hlp) {
        hlp = _hlp;
        usdc = _usdc;
        compounder = _compounder;

        hmxStakingPool = _hmxStakingPool;
        hlpStakingPool = _hlpStakingPool;

        hlpUsdcRewarder = _hlpUsdcRewarder;
        hlpEsHmxRewarder = _hlpEsHmxRewarder;
        hmxUsdcRewarder = _hmxUsdcRewarder;
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {SYBase-_deposit}
     */
    function _deposit(
        address /*tokenIn*/,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        return amountDeposited;
    }

    /**
     * @dev See {SYBase-_redeem}
     */
    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 /*amountTokenOut*/) {
        _transferOut(hlp, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
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
        res[0] = usdc;
    }

    function _redeemExternalReward() internal override {
        address[] memory pools = new address[](2);
        pools[0] = hmxStakingPool;
        pools[1] = hlpStakingPool;

        address[][] memory rewarders = new address[][](2);
        rewarders[0] = new address[](1);
        rewarders[0][0] = hmxUsdcRewarder;

        rewarders[1] = new address[](2);
        rewarders[1][0] = hlpUsdcRewarder;
        rewarders[1][1] = hlpEsHmxRewarder;

        IHMXCompounder(compounder).compound(pools, rewarders, 0, 0, new uint256[](0));
    }

    /*///////////////////////////////////////////////////////////////
                    MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address /*tokenIn*/,
        uint256 amountTokenToDeposit
    ) internal pure override returns (uint256 /*amountSharesOut*/) {
        return amountTokenToDeposit;
    }

    function _previewRedeem(
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal pure override returns (uint256 /*amountTokenOut*/) {
        return amountSharesToRedeem;
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](1);
        res[0] = hlp;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](1);
        res[0] = hlp;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == hlp;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == hlp;
    }

    function assetInfo()
        external
        view
        returns (AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (AssetType.LIQUIDITY, hlp, IERC20Metadata(hlp).decimals());
    }
}
