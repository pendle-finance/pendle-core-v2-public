// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "../../SuperComposableYield/implementations/SCYBase.sol";
import "../../interfaces/IWstETH.sol";

contract PendleStEthSCY is SCYBase {
    using SafeERC20 for IERC20;

    address public immutable stETH;
    address public immutable wstETH;

    uint256 public override scyIndexStored;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __scydecimals,
        uint8 __assetDecimals,
        address _stETH,
        address _wstETH
    ) SCYBase(_name, _symbol, __scydecimals, __assetDecimals) {
        require(_wstETH != address(0), "zero address");
        stETH = _stETH;
        wstETH = _wstETH;
        IERC20(stETH).safeIncreaseAllowance(wstETH, type(uint256).max);
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
        if (token == stETH) {
            amountScyOut = IWstETH(wstETH).wrap(amountBase);
            _afterSendToken(stETH);
            _afterReceiveToken(wstETH);
        } else {
            // 1 wstETH = 1 SCY
            amountScyOut = amountBase;
        }
    }

    function _redeem(address token, uint256 amountScy)
        internal
        virtual
        override
        returns (uint256 amountBaseOut)
    {
        if (token == stETH) {
            amountBaseOut = IWstETH(wstETH).unwrap(amountScy);
            _afterSendToken(wstETH);
            _afterReceiveToken(stETH);
        } else {
            // 1 wstETH = 1 SCY
            amountBaseOut = amountScy;
        }
    }

    /*///////////////////////////////////////////////////////////////
                               SCY-INDEX
    //////////////////////////////////////////////////////////////*/

    function scyIndexCurrent() public virtual override returns (uint256) {
        scyIndexStored = IWstETH(wstETH).stEthPerToken();
        emit UpdateScyIndex(scyIndexStored);
        return scyIndexStored;
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function getBaseTokens() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = stETH;
        res[1] = wstETH;
    }

    function isValidBaseToken(address token) public view virtual override returns (bool res) {
        res = (token == stETH || token == wstETH);
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
