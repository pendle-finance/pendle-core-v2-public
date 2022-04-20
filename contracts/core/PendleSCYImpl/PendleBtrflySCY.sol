// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
pragma abicoder v2;
import "../../SuperComposableYield/implementations/SCYBase.sol";
import "../../interfaces/IWXBTRFLY.sol";
import "../../interfaces/IREDACTEDStaking.sol";

contract PendleBtrflyScy is SCYBase {
    using SafeERC20 for IERC20;

    address public immutable BTRFLY;
    address public immutable xBTRFLY;
    address public immutable wxBTRFLY;

    uint256 public lastScyIndex;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __scydecimals,
        uint8 __assetDecimals,
        address _BTRFLY,
        address _xBTRFLY,
        address _wxBTRFLY
    ) SCYBase(_name, _symbol, __scydecimals, __assetDecimals) {
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
        returns (uint256 amountScyOut)
    {
        if (token == BTRFLY) {
            amountScyOut = IWXBTRFLY(wxBTRFLY).wrapFromBTRFLY(amountBase);
            _afterSendToken(BTRFLY);
            _afterReceiveToken(wxBTRFLY);
        } else if (token == xBTRFLY) {
            amountScyOut = IWXBTRFLY(wxBTRFLY).wrapFromxBTRFLY(amountBase);
            _afterSendToken(xBTRFLY);
            _afterReceiveToken(wxBTRFLY);
        } else {
            // 1 wxBTRFLY = 1 SCY
            amountScyOut = amountBase;
        }
    }

    function _redeem(address token, uint256 amountScy)
        internal
        virtual
        override
        returns (uint256 amountBaseOut)
    {
        if (token == BTRFLY) {
            amountBaseOut = IWXBTRFLY(wxBTRFLY).unwrapToBTRFLY(amountScy);
            _afterSendToken(wxBTRFLY);
        } else if (token == xBTRFLY) {
            amountBaseOut = IWXBTRFLY(wxBTRFLY).unwrapToxBTRFLY(amountScy);
            _afterSendToken(wxBTRFLY);
        } else {
            // 1 wxBTRFLY = 1 SCY
            amountBaseOut = amountScy;
        }
    }

    /*///////////////////////////////////////////////////////////////
                               SCY-INDEX
    //////////////////////////////////////////////////////////////*/

    function scyIndexCurrent() public virtual override returns (uint256) {
        lastScyIndex = IWXBTRFLY(wxBTRFLY).xBTRFLYValue(Math.ONE);
        return lastScyIndex;
    }

    function scyIndexStored() public view override returns (uint256) {
        return lastScyIndex;
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function getBaseTokens() public view virtual override returns (address[] memory res) {
        res = new address[](3);
        res[0] = BTRFLY;
        res[1] = xBTRFLY;
        res[2] = wxBTRFLY;
    }

    function isValidBaseToken(address token) public view virtual override returns (bool res) {
        res = (token == BTRFLY || token == xBTRFLY || token == wxBTRFLY);
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
