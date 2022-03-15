// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import "../ILiquidYieldTokenWrap.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../../libraries/math/FixedPoint.sol";

/**
# CONDITIONS TO USE THIS PRESET:
- the token's balance must be static (i.e not increase on its own). Some examples of tokens don't
satisfy this restriction is AaveV2's aToken

# OVERVIEW OF THIS PRESET
- 1 unit of YieldToken is wrapped into 1 unit of LYT
*/
abstract contract LYTWrapSingleBaseWithRewards is ERC20, ILiquidYieldTokenWrap {
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

    uint8 private immutable _lytdecimals;
    uint8 private immutable _assetDecimals;

    address public immutable baseToken;
    address public immutable yieldToken;
    uint256 public immutable rewardLength;

    uint256 internal constant INITIAL_REWARD_INDEX = 1;

    GlobalReward[] public globalReward;
    mapping(address => UserReward[]) public userReward;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __lytdecimals,
        uint8 __assetDecimals,
        address _baseToken,
        address _yieldToken,
        uint256 _rewardLength
    ) ERC20(_name, _symbol) {
        _lytdecimals = __lytdecimals;
        _assetDecimals = __assetDecimals;

        baseToken = _baseToken;
        yieldToken = _yieldToken;

        rewardLength = _rewardLength;
        for (uint256 i = 0; i < rewardLength; i++) {
            globalReward.push(GlobalReward(INITIAL_REWARD_INDEX, 0));
        }

        // Children's constructor needs to approve the address to mint the yieldToken
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function depositBaseToken(
        address recipient,
        address baseTokenIn,
        uint256 amountBaseIn,
        uint256 minAmountLytOut
    ) public virtual override returns (uint256 amountLytOut) {
        require(baseTokenIn == baseToken, "invalid base token");

        IERC20(baseTokenIn).safeTransferFrom(msg.sender, address(this), amountBaseIn);

        amountLytOut = _baseToYield(amountBaseIn);

        require(amountLytOut >= minAmountLytOut, "insufficient out");

        _mint(recipient, amountLytOut);
    }

    function redeemToBaseToken(
        address recipient,
        uint256 amountLytRedeem,
        address baseTokenOut,
        uint256 minAmountBaseOut
    ) public virtual override returns (uint256 amountBaseOut) {
        require(baseTokenOut == baseToken, "invalid base token");

        _burn(msg.sender, amountLytRedeem);

        amountBaseOut = _yieldToBase(amountLytRedeem);

        require(amountBaseOut >= minAmountBaseOut, "insufficient out");

        IERC20(baseToken).safeTransfer(recipient, amountBaseOut);
    }

    function _baseToYield(uint256 amountBase) internal virtual returns (uint256 amountYieldOut);

    function _yieldToBase(uint256 amountYield) internal virtual returns (uint256 amountBaseOut);

    /*///////////////////////////////////////////////////////////////
                DEPOSIT/REDEEM USING THE YIELD TOKEN
    //////////////////////////////////////////////////////////////*/

    function depositYieldToken(
        address recipient,
        uint256 amountYieldIn,
        uint256 minAmountLytOut
    ) public virtual override returns (uint256 amountLytOut) {
        IERC20(yieldToken).safeTransferFrom(msg.sender, address(this), amountYieldIn);

        amountLytOut = amountYieldIn;

        require(amountLytOut >= minAmountLytOut, "insufficient out");

        _mint(recipient, amountLytOut);
    }

    function redeemToYieldToken(
        address recipient,
        uint256 amountLytRedeem,
        uint256 minAmountYieldOut
    ) public virtual override returns (uint256 amountYieldOut) {
        _burn(msg.sender, amountLytRedeem);

        amountYieldOut = amountLytRedeem;

        require(amountYieldOut >= minAmountYieldOut, "insufficient out");

        IERC20(yieldToken).safeTransfer(recipient, amountYieldOut);
    }

    /*///////////////////////////////////////////////////////////////
                               LYT-INDEX
    //////////////////////////////////////////////////////////////*/
    function assetBalanceOf(address user) public virtual override returns (uint256) {
        return balanceOf(user).mulDown(lytIndexCurrent());
    }

    /// lytIndexCurrent must be non-decreasing
    function lytIndexCurrent() public virtual override returns (uint256 res);

    function lytIndexStored() public view virtual override returns (uint256 res);

    /*///////////////////////////////////////////////////////////////
                MISC METADATA FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return _lytdecimals;
    }

    function assetDecimals() public view virtual returns (uint8) {
        return _assetDecimals;
    }

    function getBaseTokens() public view override returns (address[] memory res) {
        res = new address[](1);
        res[0] = baseToken;
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    function redeemReward() public virtual override returns (uint256[] memory outAmounts) {
        updateUserReward(msg.sender);

        outAmounts = new uint256[](rewardLength);
        for (uint256 i = 0; i < rewardLength; ++i) {
            IERC20 token = _getRewardToken(i);

            outAmounts[i] = userReward[msg.sender][i].accuredReward;
            userReward[msg.sender][i].accuredReward = 0;

            globalReward[i].lastBalance -= outAmounts[i];

            if (outAmounts[i] != 0) {
                token.safeTransfer(msg.sender, outAmounts[i]);
            }
        }
    }

    function updateGlobalReward() public virtual override {
        _updateGlobalReward();
    }

    function updateUserReward(address user) public virtual override {
        _updateGlobalReward();
        _updateUserRewardSkipGlobal(user);
    }

    ///@dev this function must match with the _getRewardToken
    function getRewardTokens() public view virtual override returns (address[] memory);

    function _getRewardToken(uint256 index) internal view virtual returns (IERC20 token);

    function _updateGlobalReward() internal {
        _redeemExternalReward();

        uint256 totalLYT = totalSupply();
        for (uint256 i = 0; i < rewardLength; ++i) {
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
        for (uint256 i = 0; i < rewardLength; ++i) {
            uint256 userLastIndex = userReward[user][i].lastIndex;
            if (userLastIndex == globalReward[i].index) continue;

            uint256 rewardAmountPerLYT = globalReward[i].index - userLastIndex;
            uint256 rewardFromLYT = principle.mulDown(rewardAmountPerLYT);

            userReward[user][i].accuredReward += rewardFromLYT;
            userReward[user][i].lastIndex = globalReward[i].index;
        }
    }

    function _redeemExternalReward() internal virtual;

    /*///////////////////////////////////////////////////////////////
                            TRANSFER HOOKS
    //////////////////////////////////////////////////////////////*/
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 /*amount*/
    ) internal virtual override {
        _updateGlobalReward();
        if (from != address(0)) _updateUserRewardSkipGlobal(from);
        if (to != address(0)) _updateUserRewardSkipGlobal(to);
    }
}
