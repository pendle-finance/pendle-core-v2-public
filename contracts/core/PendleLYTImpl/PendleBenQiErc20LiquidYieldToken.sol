// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;
import "../../LiquidYieldToken/LiquidYieldTokenWrap.sol";
import "../../interfaces/IBenQiComptroller.sol";
import "../../interfaces/IJoeRouter01.sol";
import "../../interfaces/IQiErc20.sol";
import "../../interfaces/IQiToken.sol";
import "../../interfaces/IWETH.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/math/Math.sol";
import "../../libraries/math/FixedPoint.sol";

contract PendleBenQiErc20LiquidYieldToken is LiquidYieldTokenWrap {
    using SafeERC20 for IERC20;
    using FixedPoint for uint256;

    struct GlobalReward {
        uint256 index;
        uint256 lastBalance;
    }

    struct UserReward {
        uint256 lastIndex;
        uint256 accuredReward;
    }

    uint256 internal constant REWARD_LENGTH = 2;
    uint256 internal constant INITIAL_REWARD_INDEX = 1;

    address public immutable WAVAX;
    address public immutable QI;

    address public immutable comptroller;
    address public immutable baseToken;

    uint256 public lastLytIndex;

    GlobalReward[] public globalReward;
    mapping(address => UserReward[]) public userReward;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __lytdecimals,
        uint8 __assetDecimals,
        address _baseToken,
        address _yieldToken,
        address _comptroller,
        address _QI,
        address _WAVAX
    ) LiquidYieldTokenWrap(_name, _symbol, __lytdecimals, __assetDecimals, _yieldToken) {
        baseToken = _baseToken;
        comptroller = _comptroller;
        WAVAX = _WAVAX;
        QI = _QI;

        IERC20(baseToken).safeIncreaseAllowance(yieldToken, type(uint256).max);

        globalReward = [
            GlobalReward(INITIAL_REWARD_INDEX, 0),
            GlobalReward(INITIAL_REWARD_INDEX, 0)
        ];
    }

    // solhint-disable no-empty-blocks
    receive() external payable {}

    function depositBaseToken(
        address recipient,
        address baseTokenIn,
        uint256 amountBaseIn,
        uint256 minAmountLytOut
    ) public override returns (uint256 amountLytOut) {
        require(baseTokenIn == baseToken, "invalid base token");

        IERC20(baseTokenIn).safeTransferFrom(msg.sender, address(this), amountBaseIn);

        // 1 lyt = 1 qiToken, hence we can do this
        amountLytOut = _mintQiToken(amountBaseIn);

        require(amountLytOut >= minAmountLytOut, "insufficient out");

        _mint(recipient, amountLytOut);
    }

    function redeemToBaseToken(
        address recipient,
        uint256 amountLytRedeem,
        address baseTokenOut,
        uint256 minAmountBaseOut
    ) public override returns (uint256 amountBaseOut) {
        require(baseTokenOut == baseToken, "invalid base token");

        _burn(msg.sender, amountLytRedeem);

        amountBaseOut = _burnQiToken(amountLytRedeem);

        require(amountBaseOut >= minAmountBaseOut, "insufficient out");

        IERC20(baseToken).safeTransfer(recipient, amountBaseOut);
    }

    function depositYieldToken(
        address recipient,
        uint256 amountYieldIn,
        uint256 minAmountLytOut
    ) public override returns (uint256 amountLytOut) {
        IERC20(yieldToken).safeTransferFrom(msg.sender, address(this), amountYieldIn);

        amountLytOut = amountYieldIn;

        require(amountLytOut >= minAmountLytOut, "insufficient out");

        _mint(recipient, amountLytOut);
    }

    function redeemToYieldToken(
        address recipient,
        uint256 amountLytRedeem,
        uint256 minAmountYieldOut
    ) public override returns (uint256 amountYieldOut) {
        _burn(msg.sender, amountLytRedeem);

        amountYieldOut = amountLytRedeem;

        require(amountYieldOut >= minAmountYieldOut, "insufficient out");

        IERC20(yieldToken).safeTransfer(recipient, amountYieldOut);
    }

    function assetBalanceOf(address account) public override returns (uint256) {
        return balanceOf(account).mulDown(lytIndexCurrent());
    }

    function lytIndexCurrent() public override returns (uint256 res) {
        res = Math.max(lastLytIndex, IQiToken(yieldToken).exchangeRateCurrent());
        lastLytIndex = res;
        return res;
    }

    function updateUserReward(address user) public override {
        _updateGlobalReward();
        _updateUserRewardSkipGlobal(user);
    }

    function updateGlobalReward() public override {
        _updateGlobalReward();
    }

    function redeemReward() public override returns (uint256[] memory outAmounts) {
        updateUserReward(msg.sender);

        outAmounts = new uint256[](REWARD_LENGTH);
        for (uint256 i = 0; i < REWARD_LENGTH; ++i) {
            IERC20 token = _getRewardToken(i);

            outAmounts[i] = userReward[msg.sender][i].accuredReward;
            userReward[msg.sender][i].accuredReward = 0;

            globalReward[i].lastBalance -= outAmounts[i];

            if (outAmounts[i] != 0) {
                token.safeTransfer(msg.sender, outAmounts[i]);
            }
        }
    }

    function lytIndexStored() public view override returns (uint256 res) {
        res = lastLytIndex;
    }

    function getBaseTokens() public view override returns (address[] memory res) {
        res = new address[](1);
        res[0] = baseToken;
    }

    /// @dev this function must match with the _getRewardToken
    function getRewardTokens() public view override returns (address[] memory res) {
        res = new address[](REWARD_LENGTH);
        res[0] = QI;
        res[1] = WAVAX;
    }

    function _updateGlobalReward() internal {
        _claimRewardFromExternalSource();

        uint256 totalLYT = totalSupply();
        for (uint256 i = 0; i < REWARD_LENGTH; ++i) {
            IERC20 token = _getRewardToken(i);

            uint256 currentRewardBalance = token.balanceOf(address(this));

            if (totalLYT != 0) {
                globalReward[i].index += (currentRewardBalance - globalReward[i].lastBalance)
                    .divDown(totalLYT);
            }

            globalReward[i].lastBalance = currentRewardBalance;
        }
    }

    function _updateUserRewardSkipGlobal(address user) internal {
        uint256 principle = balanceOf(user);
        for (uint256 i = 0; i < REWARD_LENGTH; ++i) {
            uint256 userLastIndex = userReward[user][i].lastIndex;
            if (userLastIndex == globalReward[i].index) continue;

            uint256 rewardAmountPerLYT = globalReward[i].index - userLastIndex;
            uint256 rewardFromLYT = principle.mulDown(rewardAmountPerLYT);

            userReward[user][i].accuredReward += rewardFromLYT;
            userReward[user][i].lastIndex = globalReward[i].index;
        }
    }

    function _claimRewardFromExternalSource() internal {
        address[] memory holders = new address[](1);
        address[] memory qiTokens = new address[](1);
        holders[0] = address(this);
        qiTokens[0] = yieldToken;

        IBenQiComptroller(comptroller).claimReward(0, holders, qiTokens, false, true);
        IBenQiComptroller(comptroller).claimReward(1, holders, qiTokens, false, true);

        if (address(this).balance != 0) IWETH(WAVAX).deposit{ value: address(this).balance };
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 /*amount*/
    ) internal override {
        updateGlobalReward();
        if (from != address(0)) _updateUserRewardSkipGlobal(from);
        if (to != address(0)) _updateUserRewardSkipGlobal(to);
    }

    function _mintQiToken(uint256 amountBase) internal returns (uint256 amountQiTokenMinted) {
        uint256 preBalance = IERC20(yieldToken).balanceOf(address(this));

        IQiErc20(yieldToken).mint(amountBase);

        amountQiTokenMinted = IERC20(yieldToken).balanceOf(address(this)) - preBalance;
    }

    function _burnQiToken(uint256 amountYield) internal returns (uint256 amountBaseReceived) {
        uint256 preBalance = IERC20(baseToken).balanceOf(address(this));

        IQiErc20(yieldToken).redeem(amountYield);

        uint256 postBalance = IERC20(baseToken).balanceOf(address(this));

        amountBaseReceived = postBalance - preBalance;
    }

    function _getRewardToken(uint256 index) internal view returns (IERC20 token) {
        token = (index == 0 ? IERC20(QI) : IERC20(WAVAX));
    }
}
/*INVARIANTS TO CHECK
- all transfers are safeTransfer
- reentrancy check
*/
