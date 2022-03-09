// SPDX-License-Identifier: GPL-3.0-or-later
/*
 * MIT License
 * ===========
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 */

pragma solidity ^0.8.0;
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../../libraries/math/FixedPoint.sol";
import "../../interfaces/IPLiquidYieldToken.sol";

abstract contract PendleLiquidYieldTokenBase is IPLiquidYieldToken, ERC20 {
    uint256 private constant _INITIAL_REWARD_INDEX = 1;

    uint8 private immutable _decimals;
    uint8 public immutable underlyingDecimals;
    address public immutable underlying;

    uint256 public lastExchangeRate;

    address[] public rewardTokens;
    GlobalReward[] public globalReward;
    mapping(address => UserReward[]) public userReward;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint8 _underlyingDecimals,
        address[] memory _rewardTokens,
        address _underlying
    ) ERC20(_name, _symbol) {
        _decimals = __decimals;
        underlyingDecimals = _underlyingDecimals;
        rewardTokens = _rewardTokens;
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            globalReward.push(GlobalReward(_INITIAL_REWARD_INDEX, 0));
        }
        underlying = _underlying;
    }

    function getRewardTokens() external view returns (address[] memory res) {
        res = new address[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            res[i] = rewardTokens[i];
        }
    }

    /**
     * @notice takes in the underlying and wrap them into LYT
     * @param recipient the address to receive LYT
     * @param amountUnderlyingIn the amount of underlying to pull
     */
    function mint(address recipient, uint256 amountUnderlyingIn)
        public
        virtual
        returns (uint256 amountLytOut);

    /**
     * @notice takes in the rawToken & convert them into LYT. Swapping will be done if necessary
     * @param recipient the address to receive LYT
     * @param rawToken the rawToken to pull
     * @param amountRawIn the amount of rawToken to pull
     * @param data optional data. Can be used for swapping path etc...
     */
    function mintFromRawToken(
        address recipient,
        address rawToken,
        uint256 amountRawIn,
        uint256 minAmountLytOut,
        bytes calldata data
    ) public virtual returns (uint256 amountLytOut);

    /**
     * @notice takes in LYT and returns back the corresponding amount of underlying
     * @param recipient the address to receive LYT
     * @param amountLytIn the amount of LYT to burn
     */
    function burn(address recipient, uint256 amountLytIn)
        public
        virtual
        returns (uint256 amountUnderlyingOut);

    /**
     * @notice takes in LYT and converts all of them to rawToken
     */
    function burnToRawToken(
        address recipient,
        address rawToken,
        uint256 amountLytIn,
        uint256 minAmountRawOut,
        bytes calldata data
    ) public virtual returns (uint256 amountRawOut);

    // strictly not overridable to guarantee the definition of baseBalanceOf & exchangeRate
    function baseBalanceOf(address account) public returns (uint256) {
        return FixedPoint.mulDown(balanceOf(account), exchangeRateCurrent());
    }

    function exchangeRateCurrent() public virtual returns (uint256);

    function redeemReward() public virtual returns (uint256[] memory outAmounts);

    function updateGlobalReward() public virtual;

    function updateUserReward(address user) public virtual {
        updateGlobalReward();
        _updateUserRewardSkipGlobal(user);
    }

    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return _decimals;
    }

    function _updateUserRewardSkipGlobal(address user) internal virtual;

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal virtual override {
        updateGlobalReward();
        if (from != address(0)) _updateUserRewardSkipGlobal(from);
        if (to != address(0)) _updateUserRewardSkipGlobal(to);
    }
}
