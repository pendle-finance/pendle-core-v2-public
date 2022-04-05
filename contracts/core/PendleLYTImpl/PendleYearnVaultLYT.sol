// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;
import "../../LiquidYieldToken/implementations/LYTBase.sol";
import "../../interfaces/IYearnVault.sol";

contract PendleYearnVaultLYT is LYTBase {
    using SafeERC20 for IERC20;

    address public immutable underlying;
    address public immutable yvToken;

    uint256 public lastLytIndex;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __lytdecimals,
        uint8 __assetDecimals,
        address _underlying,
        address _yvToken
    ) LYTBase(_name, _symbol, __lytdecimals, __assetDecimals) {
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
        returns (uint256 amountLytOut)
    {
        if (token == yvToken) {
            amountLytOut = amountBase;
        } else {
            // must be underlying
            IYearnVault(yvToken).deposit(amountBase);
            _afterSendToken(underlying);
            amountLytOut = _afterReceiveToken(yvToken);
        }
    }

    function _redeem(address token, uint256 amountLyt)
        internal
        virtual
        override
        returns (uint256 amountBaseOut)
    {
        if (token == yvToken) {
            amountBaseOut = amountLyt;
        } else {
            // must be underlying
            IYearnVault(yvToken).withdraw(amountLyt);
            _afterSendToken(yvToken);
            amountBaseOut = _afterReceiveToken(underlying);
        }
    }

    /*///////////////////////////////////////////////////////////////
                               LYT-INDEX
    //////////////////////////////////////////////////////////////*/

    function lytIndexCurrent() public virtual override returns (uint256 res) {
        res = FixedPoint.max(lastLytIndex, IYearnVault(yvToken).pricePerShare());
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
        res = new address[](1);
        res[0] = underlying;
    }

    function isValidBaseToken(address token) public view virtual override returns (bool res) {
        res = (token == underlying);
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
