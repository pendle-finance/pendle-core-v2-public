// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;
import "../../LiquidYieldToken/implementations/LYTBase.sol";
import "../../interfaces/IWXBTRFLY.sol";
import "../../interfaces/IREDACTEDStaking.sol";

contract PendleBtrflyLYT is LYTBase {
    using SafeERC20 for IERC20;

    address internal immutable BTRFLY;
    address internal immutable xBTRFLY;
    address internal immutable wxBTRFLY;

    uint256 internal lastLytIndex;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __lytdecimals,
        uint8 __assetDecimals,
        address _BTRFLY,
        address _xBTRFLY,
        address _wxBTRFLY
    ) LYTBase(_name, _symbol, __lytdecimals, __assetDecimals) {
        BTRFLY = _BTRFLY;
        xBTRFLY = _xBTRFLY;
        wxBTRFLY = _wxBTRFLY;
        IERC20(BTRFLY).safeIncreaseAllowance(wxBTRFLY, type(uint256).max);
        IERC20(xBTRFLY).safeIncreaseAllowance(wxBTRFLY, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/
    function _deposit(address token, uint256 amountBase)
        internal
        virtual
        override
        returns (uint256 amountLytOut)
    {
        if (token == BTRFLY) {
            amountLytOut = IWXBTRFLY(wxBTRFLY).wrapFromBTRFLY(amountBase);
        } else if (token == xBTRFLY) {
            amountLytOut = IWXBTRFLY(wxBTRFLY).wrapFromxBTRFLY(amountBase);
        } else {
            // 1 wxBTRFLY = 1 LYT
            amountLytOut = amountBase;
        }
    }

    function _redeem(address token, uint256 amountLyt)
        internal
        virtual
        override
        returns (uint256 amountBaseOut)
    {
        if (token == BTRFLY) {
            amountBaseOut = IWXBTRFLY(wxBTRFLY).unwrapToBTRFLY(amountLyt);
        } else if (token == xBTRFLY) {
            amountBaseOut = IWXBTRFLY(wxBTRFLY).unwrapToxBTRFLY(amountLyt);
        } else {
            // 1 wxBTRFLY = 1 LYT
            amountBaseOut = amountLyt;
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
