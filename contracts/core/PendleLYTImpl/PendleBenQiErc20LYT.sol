// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;
import "../../LiquidYieldToken/implementations/LYTWrapSingleBaseWithRewards.sol";
import "../../interfaces/IQiErc20.sol";
import "../../interfaces/IBenQiComptroller.sol";
import "../../interfaces/IWETH.sol";

contract PendleBenQiErc20LYT is LYTWrapSingleBaseWithRewards {
    using SafeERC20 for IERC20;

    address internal immutable qi;
    address internal immutable wavax;
    address internal immutable comptroller;

    uint256 internal lastLytIndex;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __lytdecimals,
        uint8 __assetDecimals,
        address _baseToken,
        address _yieldToken,
        address _comptroller,
        address _qi,
        address _wavax
    )
        LYTWrapSingleBaseWithRewards(
            _name,
            _symbol,
            __lytdecimals,
            __assetDecimals,
            _baseToken,
            _yieldToken,
            2
        )
    {
        qi = _qi;
        wavax = _wavax;
        comptroller = _comptroller;
        IERC20(baseToken).safeIncreaseAllowance(yieldToken, type(uint256).max);
    }

    // solhint-disable no-empty-blocks
    receive() external payable {}

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/
    function _baseToYield(uint256 amountBase)
        internal
        virtual
        override
        returns (uint256 amountYieldOut)
    {
        uint256 preBalance = IERC20(yieldToken).balanceOf(address(this));

        IQiErc20(yieldToken).mint(amountBase);

        amountYieldOut = IERC20(yieldToken).balanceOf(address(this)) - preBalance;
    }

    function _yieldToBase(uint256 amountYield)
        internal
        virtual
        override
        returns (uint256 amountBaseOut)
    {
        uint256 preBalance = IERC20(baseToken).balanceOf(address(this));

        IQiErc20(yieldToken).redeem(amountYield);

        uint256 postBalance = IERC20(baseToken).balanceOf(address(this));

        amountBaseOut = postBalance - preBalance;
    }

    /*///////////////////////////////////////////////////////////////
                               LYT-INDEX
    //////////////////////////////////////////////////////////////*/

    function lytIndexCurrent() public virtual override returns (uint256 res) {
        res = FixedPoint.max(lastLytIndex, IQiToken(yieldToken).exchangeRateCurrent());
        lastLytIndex = res;
        return res;
    }

    function lytIndexStored() public view override returns (uint256 res) {
        res = lastLytIndex;
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    function _redeemExternalReward() internal override {
        address[] memory holders = new address[](1);
        address[] memory qiTokens = new address[](1);
        holders[0] = address(this);
        qiTokens[0] = yieldToken;

        IBenQiComptroller(comptroller).claimReward(0, holders, qiTokens, false, true);
        IBenQiComptroller(comptroller).claimReward(1, holders, qiTokens, false, true);

        if (address(this).balance != 0) IWETH(wavax).deposit{ value: address(this).balance };
    }

    /*///////////////////////////////////////////////////////////////
                VIEW FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function getRewardTokens() public view override returns (address[] memory res) {
        res = new address[](rewardLength);
        res[0] = qi;
        res[1] = wavax;
    }

    function _getRewardToken(uint256 index) internal view override returns (IERC20 token) {
        token = (index == 0 ? IERC20(qi) : IERC20(wavax));
    }
}
/*INVARIANTS TO CHECK
- all transfers are safeTransfer
- reentrancy check
*/
