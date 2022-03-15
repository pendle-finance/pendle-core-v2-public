// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;
import "../../LiquidYieldToken/implementations/LYTWrap.sol";
import "../../interfaces/IWXBTRFLY.sol";
import "../../interfaces/IREDACTEDStaking.sol";

contract PendleBtrflyLYT is LYTWrap {
    using SafeERC20 for IERC20;

    address internal immutable BTRFLY;
    address internal immutable xBTRFLY;
    address internal immutable wxBTRFLY;
    address internal immutable staking;

    uint256 internal lastLytIndex;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __lytdecimals,
        uint8 __assetDecimals,
        address _REDACTEDStaking,
        address _BTRFLY,
        address _xBTRFLY,
        address _wxBTRFLY
    ) LYTWrap(_name, _symbol, __lytdecimals, __assetDecimals, _wxBTRFLY) {
        staking = _REDACTEDStaking;
        BTRFLY = _BTRFLY;
        xBTRFLY = _xBTRFLY;
        wxBTRFLY = _wxBTRFLY;
        IERC20(xBTRFLY).safeIncreaseAllowance(wxBTRFLY, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/
    function _baseToYield(address token, uint256)
        internal
        virtual
        override
        returns (uint256 amountYieldOut)
    {
        if (token == BTRFLY) {
            uint256 balanceBTRFLY = IERC20(BTRFLY).balanceOf(address(this));
            _doStaking(balanceBTRFLY);
        }

        uint256 balanceXBTRFLY = IERC20(xBTRFLY).balanceOf(address(this));
        amountYieldOut = IWXBTRFLY(wxBTRFLY).wrapFromxBTRFLY(balanceXBTRFLY);
    }

    function _doStaking(uint256 amount) internal {
        require(IREDACTEDStaking(staking).warmupPeriod() == 0, "WARMUP_PERIOD_NOT_ZERO");
        IREDACTEDStaking(staking).stake(amount, address(this));
        IREDACTEDStaking(staking).claim(address(this));
    }

    function _yieldToBase(address token, uint256 amountYield)
        internal
        virtual
        override
        returns (uint256 amountBaseOut)
    {
        uint256 amountXBTRFLYout = IWXBTRFLY(wxBTRFLY).unwrapToxBTRFLY(amountYield);
        if (token == xBTRFLY) {
            amountBaseOut = amountXBTRFLYout;
        } else {
            IREDACTEDStaking(staking).unstake(amountXBTRFLYout, true);
            amountBaseOut = IERC20(BTRFLY).balanceOf(address(this));
        }
    }

    /*///////////////////////////////////////////////////////////////
                               LYT-INDEX
    //////////////////////////////////////////////////////////////*/

    function lytIndexCurrent() public virtual override returns (uint256 res) {
        res = FixedPoint.max(lastLytIndex, IWXBTRFLY(wxBTRFLY).xBTRFLYValue(FixedPoint.ONE));
        lastLytIndex = res;
        return res;
    }

    function lytIndexStored() public view override returns (uint256 res) {
        res = lastLytIndex;
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function getBaseTokens() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = BTRFLY;
        res[1] = xBTRFLY;
    }

    function isValidBaseToken(address token) public view virtual override returns (bool res) {
        res = (token == BTRFLY || token == xBTRFLY);
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    //solhint-disable-next-line no-empty-blocks
    function redeemReward(address user) public virtual override returns (uint256[] memory) {}

    //solhint-disable-next-line no-empty-blocks
    function updateGlobalReward() public virtual override {}

    //solhint-disable-next-line no-empty-blocks
    function updateUserReward(address user) public virtual override {}

    function getRewardTokens() public view virtual returns (address[] memory res) {
        res = new address[](0);
    }

    //solhint-disable-next-line no-empty-blocks
    function _redeemExternalReward() internal virtual {}
}
