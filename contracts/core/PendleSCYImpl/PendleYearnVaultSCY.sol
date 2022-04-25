// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../SuperComposableYield/implementations/SCYBase.sol";
import "../../interfaces/IYearnVault.sol";

contract PendleYearnVaultScy is SCYBase {
    using SafeERC20 for IERC20;

    address public immutable underlying;
    address public immutable yvToken;

    uint256 public override scyIndexStored;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __scydecimals,
        uint8 __assetDecimals,
        bytes32 __assetId,
        address _underlying,
        address _yvToken
    ) SCYBase(_name, _symbol, __scydecimals, __assetDecimals, __assetId) {
        require(_yvToken != address(0), "zero address");
        yvToken = _yvToken;
        underlying = _underlying;
        IERC20(underlying).safeIncreaseAllowance(yvToken, type(uint256).max);
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
        if (token == yvToken) {
            amountScyOut = amountBase;
        } else {
            // must be underlying
            IYearnVault(yvToken).deposit(amountBase); // ignore return
            _afterSendToken(underlying);
            amountScyOut = _afterReceiveToken(yvToken);
        }
    }

    function _redeem(address token, uint256 amountScy)
        internal
        virtual
        override
        returns (uint256 amountBaseOut)
    {
        if (token == yvToken) {
            amountBaseOut = amountScy;
        } else {
            // must be underlying
            IYearnVault(yvToken).withdraw(amountScy); // ignore return
            _afterSendToken(yvToken);
            amountBaseOut = _afterReceiveToken(underlying);
        }
    }

    /*///////////////////////////////////////////////////////////////
                               SCY-INDEX
    //////////////////////////////////////////////////////////////*/

    function scyIndexCurrent() public virtual override returns (uint256 res) {
        scyIndexStored = IYearnVault(yvToken).pricePerShare();
        emit UpdateScyIndex(scyIndexStored);
        return scyIndexStored;
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function getBaseTokens() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = underlying;
        res[1] = yvToken;
    }

    function isValidBaseToken(address token) public view virtual override returns (bool) {
        return token == underlying || token == yvToken;
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
