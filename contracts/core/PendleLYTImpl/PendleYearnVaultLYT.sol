// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;
import "../../LiquidYieldToken/implementations/LYTWrap.sol";
import "../../interfaces/IYearnVault.sol";

contract PendleYearnVaultLYT is LYTWrap {
    using SafeERC20 for IERC20;

    address internal immutable underlying;

    uint256 internal lastLytIndex;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __lytdecimals,
        uint8 __assetDecimals,
        address _underlying,
        address _yieldToken
    ) LYTWrap(_name, _symbol, __lytdecimals, __assetDecimals, _yieldToken) {
        underlying = _underlying;
        IERC20(underlying).safeIncreaseAllowance(yieldToken, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _baseToYield(address, uint256 amountBase)
        internal
        virtual
        override
        returns (uint256 amountYieldOut)
    {
        amountYieldOut = IYearnVault(yieldToken).deposit(amountBase);
    }

    function _yieldToBase(address, uint256 amountYield)
        internal
        virtual
        override
        returns (uint256 amountBaseOut)
    {
        amountBaseOut = IYearnVault(yieldToken).withdraw(amountYield);
    }

    /*///////////////////////////////////////////////////////////////
                               LYT-INDEX
    //////////////////////////////////////////////////////////////*/

    function lytIndexCurrent() public virtual override returns (uint256 res) {
        res = FixedPoint.max(lastLytIndex, IYearnVault(yieldToken).pricePerShare());
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
