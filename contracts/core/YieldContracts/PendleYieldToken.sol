// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../interfaces/ISuperComposableYield.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPPrincipalToken.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../libraries/math/Math.sol";
import "../../libraries/helpers/ArrayLib.sol";
import "../../interfaces/IPYieldContractFactory.sol";
import "../../libraries/SCY/SCYUtils.sol";
import "../../libraries/helpers/MiniHelpers.sol";
import "../../libraries/RewardManagerAbstract.sol";
import "../PendleERC20Permit.sol";
import "./InterestManagerYT.sol";

/**
Invariances to maintain:
- address(0) & address(this) should never have any rewards & activeBalance accounting done. This is
    guaranteed by address(0) & address(this) check in each updateForTwo function
*/
contract PendleYieldToken is
    IPYieldToken,
    PendleERC20Permit,
    RewardManagerAbstract,
    InterestManagerYT
{
    using Math for uint256;
    using SafeERC20 for IERC20;
    using ArrayLib for uint256[];

    struct PostExpiryData {
        uint128 firstScyIndex;
        mapping(address => uint256) firstRewardIndex;
        mapping(address => uint256) userRewardOwed;
    }

    address public immutable SCY;
    address public immutable PT;
    address public immutable factory;
    uint256 public immutable expiry;

    uint128 public scyReserve;
    uint128 internal _scyIndexStored;

    PostExpiryData public postExpiry;

    modifier updateData() {
        if (isExpired()) _setPostExpiryData();
        _;
        _updateScyReserve();
    }

    constructor(
        address _SCY,
        address _PT,
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 _expiry
    ) PendleERC20Permit(_name, _symbol, __decimals) {
        SCY = _SCY;
        PT = _PT;
        expiry = _expiry;
        factory = msg.sender;
    }

    /// @notice Tokenize SCY into PT + YT of equal qty. Every unit of underlying of SCY will create 1 PT + 1 YT
    function mintPY(address receiverPT, address receiverYT)
        external
        nonReentrant
        updateData
        returns (uint256 amountPYOut)
    {
        require(!isExpired(), "yield contract expired");

        uint256 amountScyToMint = _getFloatingScyAmount();

        amountPYOut = _calcPYToMint(amountScyToMint);

        _mint(receiverYT, amountPYOut);

        IPPrincipalToken(PT).mintByYT(receiverPT, amountPYOut);
    }

    /// @dev this function converts PY tokens into scy, but interests & rewards are not redeemed at the same time
    function redeemPY(address receiver)
        external
        nonReentrant
        updateData
        returns (uint256 amountScyOut)
    {
        address[] memory receivers = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        (receivers[0], amounts[0]) = (receiver, type(uint256).max);

        (amountScyOut, ) = _redeemPY(receivers, amounts);
    }

    /// @dev this function limit how much each receiver will receive. For example, if the totalOut is 100,
    /// and the max are 50 30 INF, the first receiver will receive 50, the second will receive 30, and the third will receive 20.
    /// @dev intended to mostly be used by Pendle router
    function redeemPY(address[] calldata receivers, uint256[] calldata maxAmountScyOuts)
        external
        nonReentrant
        updateData
        returns (uint256 totalAmountScyOut)
    {
        require(receivers.length == maxAmountScyOuts.length, "not same length");
        require(receivers.length != 0, "empty array");
        (totalAmountScyOut, ) = _redeemPY(receivers, maxAmountScyOuts);
    }

    /**
    * @dev With YT yielding interest in the form of SCY, which is redeemable by users, the reward
    distribution should be based on the amount of SCYs that their YT currently represent, plus their
    dueInterest. It has been proven and tested that _rewardSharesUser will not change over time,
    unless users redeem their dueInterest or redeemPY. Due to this, it is required to update users'
    accruedReward STRICTLY BEFORE transferring out their interest.
    */
    function redeemDueInterestAndRewards(
        address user,
        bool redeemInterest,
        bool redeemRewards
    ) external nonReentrant updateData returns (uint256 interestOut, uint256[] memory rewardsOut) {
        require(redeemInterest || redeemRewards, "nothing to redeem");

        // if redeemRewards == true, this line must be here for obvious reason
        // if redeemInterest == true, this line must be here because of the reason above
        _updateAndDistributeRewards(user);

        if (redeemRewards) {
            rewardsOut = _doTransferOutRewards(user, user);
            emit RedeemRewards(user, rewardsOut);
        } else {
            address[] memory tokens = getRewardTokens();
            rewardsOut = new uint256[](tokens.length);
        }

        if (redeemInterest) {
            _distributeInterest(user);
            interestOut = _doTransferOutInterest(user, SCY, factory);
            emit RedeemInterest(user, interestOut);
        } else {
            interestOut = 0;
        }
    }

    function redeemRewardsPostExpiryForTreasury()
        external
        nonReentrant
        updateData
        returns (uint256[] memory rewardsOut)
    {
        require(isExpired(), "not expired");

        address[] memory tokens = getRewardTokens();
        uint256[] memory rewardOuts = new uint256[](tokens.length);

        _redeemExternalReward();

        for (uint256 i = 0; i < tokens.length; i++) {
            rewardOuts[i] = _selfBalance(tokens[i]) - postExpiry.userRewardOwed[tokens[i]];
        }

        _transferOut(tokens, IPYieldContractFactory(factory).treasury(), rewardsOut);
    }

    function rewardIndexesCurrent() external override returns (uint256[] memory) {
        return ISuperComposableYield(SCY).rewardIndexesCurrent();
    }

    /// @dev maximize the current rate with the previous rate to guarantee non-decreasing rate
    function scyIndexCurrent() public returns (uint256 currentIndex) {
        currentIndex = Math.max(ISuperComposableYield(SCY).exchangeRate(), _scyIndexStored);
        _scyIndexStored = currentIndex.Uint128();
    }

    function scyIndexStored() public view returns (uint256) {
        return _scyIndexStored;
    }

    function isExpired() public view returns (bool) {
        return MiniHelpers.isCurrentlyExpired(expiry);
    }

    function _redeemPY(address[] memory receivers, uint256[] memory maxAmountScyOuts)
        internal
        returns (uint256 totalScyToReceivers, uint256 scyInterestAfterExpiry)
    {
        uint256 amountPYToRedeem = _getAmountPYToRedeem();
        IPPrincipalToken(PT).burnByYT(address(this), amountPYToRedeem);
        if (!isExpired()) _burn(address(this), amountPYToRedeem);

        (totalScyToReceivers, scyInterestAfterExpiry) = _calcScyRedeemableFromPY(amountPYToRedeem);

        if (scyInterestAfterExpiry != 0) {
            address treasury = IPYieldContractFactory(factory).treasury();
            _transferOut(SCY, treasury, scyInterestAfterExpiry);
        }

        // all the leftover SCY will be transferred to the last receiver
        maxAmountScyOuts[maxAmountScyOuts.length - 1] = type(uint256).max;
        _transferOutMaxMulti(SCY, totalScyToReceivers, receivers, maxAmountScyOuts);
    }

    function _calcPYToMint(uint256 amountScy) internal returns (uint256 amountPY) {
        // doesn't matter before or after expiry, since mintPY is only allowed before expiry
        return SCYUtils.scyToAsset(scyIndexCurrent(), amountScy);
    }

    function _calcScyRedeemableFromPY(uint256 amountPY)
        internal
        returns (uint256 scyToUser, uint256 scyInterestAfterExpiry)
    {
        scyToUser = SCYUtils.assetToScy(scyIndexCurrent(), amountPY);
        if (isExpired()) {
            uint256 totalScyRedeemable = SCYUtils.assetToScy(postExpiry.firstScyIndex, amountPY);
            scyInterestAfterExpiry = totalScyRedeemable - scyToUser;
        }
    }

    function _getAmountPYToRedeem() internal view returns (uint256) {
        if (!isExpired()) return Math.min(_selfBalance(PT), balanceOf(address(this)));
        else return _selfBalance(PT);
    }

    function _updateScyReserve() internal virtual {
        scyReserve = _selfBalance(SCY).Uint128();
    }

    function _getFloatingScyAmount() internal view returns (uint256 amount) {
        amount = _selfBalance(SCY) - scyReserve;
        require(amount > 0, "RECEIVE_ZERO");
    }

    function _setPostExpiryData() internal {
        PostExpiryData storage local = postExpiry;
        if (local.firstScyIndex != 0) return; // already set

        _redeemExternalReward(); // do a final redeem. All the future reward income will belong to the treasury

        local.firstScyIndex = scyIndexCurrent().Uint128();
        address[] memory rewardTokens = ISuperComposableYield(SCY).getRewardTokens();
        uint256[] memory rewardIndexes = ISuperComposableYield(SCY).rewardIndexesCurrent();
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            local.firstRewardIndex[rewardTokens[i]] = rewardIndexes[i];
            local.userRewardOwed[rewardTokens[i]] = _selfBalance(rewardTokens[i]);
        }
    }

    /*///////////////////////////////////////////////////////////////
                               INTEREST-RELATED
    //////////////////////////////////////////////////////////////*/

    function _getInterestIndex() internal virtual override returns (uint256 index) {
        if (isExpired()) index = postExpiry.firstScyIndex;
        else index = scyIndexCurrent();
    }

    function _YTbalance(address user) internal view override returns (uint256) {
        return balanceOf(user);
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    function getRewardTokens() public view returns (address[] memory) {
        return ISuperComposableYield(SCY).getRewardTokens();
    }

    function _doTransferOutRewards(address user, address receiver)
        internal
        virtual
        override
        returns (uint256[] memory rewardAmounts)
    {
        address[] memory tokens = getRewardTokens();

        if (isExpired()) {
            // post-expiry, all incoming rewards will go to the treasury
            // hence, we can save users one _redeemExternal here
            for (uint256 i = 0; i < tokens.length; i++)
                postExpiry.userRewardOwed[tokens[i]] -= userReward[tokens[i]][user].accrued;
            rewardAmounts = __doTransferOutRewardsLocal(tokens, user, receiver);
        } else {
            _redeemExternalReward();
            rewardAmounts = __doTransferOutRewardsLocal(tokens, user, receiver);
        }
    }

    function __doTransferOutRewardsLocal(
        address[] memory tokens,
        address user,
        address receiver
    ) internal returns (uint256[] memory rewardAmounts) {
        address treasury = IPYieldContractFactory(factory).treasury();
        uint256 feeRate = IPYieldContractFactory(factory).rewardFeeRate();

        rewardAmounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 rewardPreFee = userReward[tokens[i]][user].accrued;
            userReward[tokens[i]][user].accrued = 0;

            uint256 feeAmount = rewardPreFee.mulDown(feeRate);
            rewardAmounts[i] = rewardPreFee - feeAmount;

            _transferOut(tokens[i], treasury, feeAmount);
            _transferOut(tokens[i], receiver, rewardAmounts[i]);
        }
    }

    function _redeemExternalReward() internal virtual override {
        ISuperComposableYield(SCY).claimRewards(address(this));
    }

    /// @dev effectively returning the amount of SCY generating rewards for this user
    function _rewardSharesUser(address user) internal view virtual override returns (uint256) {
        uint256 index = userInterest[user].index;
        if (index == 0) return 0;
        return SCYUtils.assetToScy(index, balanceOf(user)) + userInterest[user].accrued;
    }

    function _updateRewardIndex()
        internal
        override
        returns (address[] memory tokens, uint256[] memory indexes)
    {
        tokens = getRewardTokens();
        if (isExpired()) {
            indexes = new uint256[](tokens.length);
            for (uint256 i = 0; i < tokens.length; i++)
                indexes[i] = postExpiry.firstRewardIndex[tokens[i]];
        } else {
            indexes = ISuperComposableYield(SCY).rewardIndexesCurrent();
        }
    }

    //solhint-disable-next-line ordering
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        _updateAndDistributeRewardsForTwo(from, to);
        _distributeInterestForTwo(from, to);
    }
}
