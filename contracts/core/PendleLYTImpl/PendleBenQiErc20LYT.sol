// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;
import "../../LiquidYieldToken/implementations/LYTWrapWithRewards.sol";
import "../../interfaces/IQiErc20.sol";
import "../../interfaces/IBenQiComptroller.sol";
import "../../interfaces/IWETH.sol";

contract PendleBenQiErc20LYT is LYTWrapWithRewards {
    using SafeERC20 for IERC20;

    address internal immutable underlying;
    address internal immutable qi;
    address internal immutable wavax;
    address internal immutable comptroller;

    uint256 internal lastLytIndex;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __lytdecimals,
        uint8 __assetDecimals,
        address _underlying,
        address _yieldToken,
        address _comptroller,
        address _qi,
        address _wavax
    ) LYTWrapWithRewards(_name, _symbol, __lytdecimals, __assetDecimals, _yieldToken, 2) {
        underlying = _underlying;
        qi = _qi;
        wavax = _wavax;
        comptroller = _comptroller;
        IERC20(underlying).safeIncreaseAllowance(yieldToken, type(uint256).max);
    }

    // solhint-disable no-empty-blocks
    receive() external payable {}

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/
    function _baseToYield(address, uint256 amountBase)
        internal
        virtual
        override
        returns (uint256 amountYieldOut)
    {
        uint256 preBalance = IERC20(yieldToken).balanceOf(address(this));

        IQiErc20(yieldToken).mint(amountBase);

        amountYieldOut = IERC20(yieldToken).balanceOf(address(this)) - preBalance;
    }

    function _yieldToBase(address, uint256 amountYield)
        internal
        virtual
        override
        returns (uint256 amountBaseOut)
    {
        IQiErc20(yieldToken).redeem(amountYield);

        amountBaseOut = IERC20(underlying).balanceOf(address(this));
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

    function getRewardTokens() public view override returns (address[] memory res) {
        res = new address[](rewardLength);
        res[0] = qi;
        res[1] = wavax;
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function getBaseTokens() public view virtual override returns (address[] memory res) {
        res = new address[](1);
        res[0] = underlying;
    }

    function isValidBaseToken(address token) public view virtual override returns (bool res) {
        res = (token == underlying);
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
}
