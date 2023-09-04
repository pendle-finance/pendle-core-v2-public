// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../SYBaseWithRewards.sol";
import "../../../../interfaces/HMX/IHMXCompounder.sol";
import "../../../../interfaces/HMX/IHLPStaking.sol";

contract PendleHlpSY is SYBaseWithRewards {
    address public immutable hlp;
    address public immutable usdc;
    address public immutable compounder;

    address public immutable hlpStakingPool;

    address public immutable hmxStakingPool;
    address public immutable hmxUsdcRewarder;
    address public immutable hmxEsHmxRewarder;
    address public immutable hmxDpRewarder;

    constructor(
        string memory _name,
        string memory _symbol,
        address _hlp,
        address _usdc,
        address _compounder,
        address _hlpStakingPool,
        address _hmxStakingPool,
        address _hmxUsdcRewarder,
        address _hmxEsHmxRewarder,
        address _hmxDpRewarder
    ) SYBaseWithRewards(_name, _symbol, _hlp) {
        hlp = _hlp;
        usdc = _usdc;
        compounder = _compounder;

        hlpStakingPool = _hlpStakingPool;

        hmxStakingPool = _hmxStakingPool;
        hmxUsdcRewarder = _hmxUsdcRewarder;
        hmxEsHmxRewarder = _hmxEsHmxRewarder;
        hmxDpRewarder = _hmxDpRewarder;

        _safeApproveInf(hlp, hlpStakingPool);
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
        IHLPStaking(hlpStakingPool).deposit(address(this), amountDeposited);
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
        IHLPStaking(hlpStakingPool).withdraw(amountSharesToRedeem);
        _transferOut(hlp, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

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

        /* Can't use .getAllRewarders here because HMX has not configured it */
        address[][] memory rewarders = new address[][](2);
        rewarders[0] = new address[](3);
        rewarders[0][0] = hmxUsdcRewarder;
        rewarders[0][1] = hmxEsHmxRewarder;
        rewarders[0][2] = hmxDpRewarder;

        /* Surge HLP programme is redundent but that's okay  */
        rewarders[1] = IHLPStaking(hlpStakingPool).getRewarders();

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
