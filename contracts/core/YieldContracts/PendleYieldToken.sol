// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../interfaces/ISuperComposableYield.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPPrincipalToken.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../libraries/math/Math.sol";
import "../../libraries/helpers/ArrayLib.sol";
import "../../interfaces/IPYieldContractFactory.sol";
import "../../libraries/SCY/SCYUtils.sol";
import "../../libraries/Errors.sol";
import "../../libraries/helpers/MiniHelpers.sol";
import "../../libraries/RewardManagerAbstract.sol";
import "../PendleERC20Permit.sol";
import "./InterestManagerYT.sol";

/**
Invariance to maintain:
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
        uint128 firstPYIndex;
        uint128 totalScyInterestForTreasury;
        mapping(address => uint256) firstRewardIndex;
        mapping(address => uint256) userRewardOwed;
    }

    address public immutable SCY;
    address public immutable PT;
    address public immutable factory;
    uint256 public immutable expiry;

    uint128 public scyReserve;
    uint128 internal _pyIndexStored;

    PostExpiryData public postExpiry;

    modifier updateData() {
        if (isExpired()) _setPostExpiryData();
        _;
        _updateScyReserve();
    }

    modifier notExpired() {
        if (isExpired()) revert Errors.YCExpired();
        _;
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
        notExpired
        updateData
        returns (uint256 amountPYOut)
    {
        address[] memory receiverPTs = new address[](1);
        address[] memory receiverYTs = new address[](1);
        uint256[] memory amountScyToMints = new uint256[](1);

        (receiverPTs[0], receiverYTs[0], amountScyToMints[0]) = (
            receiverPT,
            receiverYT,
            _getFloatingScyAmount()
        );

        uint256[] memory amountPYOuts = _mintPY(receiverPTs, receiverYTs, amountScyToMints);
        amountPYOut = amountPYOuts[0];
    }

    /// @notice Tokenize SCY into PT + YT of equal qty. Every unit of underlying of SCY will create 1 PT + 1 YT
    function mintPYMulti(
        address[] calldata receiverPTs,
        address[] calldata receiverYTs,
        uint256[] calldata amountScyToMints
    ) external nonReentrant notExpired updateData returns (uint256[] memory amountPYOuts) {
        uint256 length = receiverPTs.length;

        if (receiverYTs.length != length && amountScyToMints.length == length)
            revert Errors.ArrayLengthMismatch();
        if (length == 0) revert Errors.ArrayEmpty();

        uint256 totalScyToMint = amountScyToMints.sum();
        if (totalScyToMint > _getFloatingScyAmount())
            revert Errors.YieldContractInsufficientScy(totalScyToMint, _getFloatingScyAmount());

        amountPYOuts = _mintPY(receiverPTs, receiverYTs, amountScyToMints);
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
        (receivers[0], amounts[0]) = (receiver, _getAmountPYToRedeem());

        uint256[] memory amountScyOuts;
        amountScyOuts = _redeemPY(receivers, amounts);

        amountScyOut = amountScyOuts[0];
    }

    /// @dev this function limit how much each receiver will receive. For example, if the totalOut is 100,
    /// and the max are 50 30 INF, the first receiver will receive 50, the second will receive 30, and the third will receive 20.
    /// @dev intended to mostly be used by Pendle router
    function redeemPYMulti(address[] calldata receivers, uint256[] calldata amountPYToRedeems)
        external
        nonReentrant
        updateData
        returns (uint256[] memory amountScyOuts)
    {
        if (receivers.length != amountPYToRedeems.length) revert Errors.ArrayLengthMismatch();
        if (receivers.length == 0) revert Errors.ArrayEmpty();
        amountScyOuts = _redeemPY(receivers, amountPYToRedeems);
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
        if (!redeemInterest && !redeemRewards) revert Errors.YCNothingToRedeem();

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

    function redeemInterestAndRewardsPostExpiryForTreasury()
        external
        nonReentrant
        updateData
        returns (uint256 interestOut, uint256[] memory rewardsOut)
    {
        if (!isExpired()) revert Errors.YCNotExpired();

        address treasury = IPYieldContractFactory(factory).treasury();

        address[] memory tokens = getRewardTokens();
        rewardsOut = new uint256[](tokens.length);

        _redeemExternalReward();

        for (uint256 i = 0; i < tokens.length; i++) {
            rewardsOut[i] = _selfBalance(tokens[i]) - postExpiry.userRewardOwed[tokens[i]];
        }

        _transferOut(tokens, treasury, rewardsOut);

        interestOut = postExpiry.totalScyInterestForTreasury;
        postExpiry.totalScyInterestForTreasury = 0;
        _transferOut(SCY, treasury, interestOut);
    }

    function rewardIndexesCurrent() external override nonReentrant returns (uint256[] memory) {
        return ISuperComposableYield(SCY).rewardIndexesCurrent();
    }

    /// @dev maximize the current rate with the previous rate to guarantee non-decreasing rate
    function pyIndexCurrent() public nonReentrant returns (uint256 currentIndex) {
        currentIndex = _pyIndexCurrent();
    }

    function setPostExpiryData() external nonReentrant {
        if (isExpired()) {
            _setPostExpiryData();
        }
    }

    function getPostExpiryData()
        external
        view
        returns (
            uint256 firstPYIndex,
            uint256 totalScyInterestForTreasury,
            uint256[] memory firstRewardIndexes,
            uint256[] memory userRewardOwed
        )
    {
        if (postExpiry.firstPYIndex == 0) revert Errors.YCPostExpiryDataNotSet();

        firstPYIndex = postExpiry.firstPYIndex;
        totalScyInterestForTreasury = postExpiry.totalScyInterestForTreasury;

        address[] memory tokens = getRewardTokens();
        firstRewardIndexes = new uint256[](tokens.length);
        userRewardOwed = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; ++i) {
            firstRewardIndexes[i] = postExpiry.firstRewardIndex[tokens[i]];
            userRewardOwed[i] = postExpiry.userRewardOwed[tokens[i]];
        }
    }

    function _mintPY(
        address[] memory receiverPTs,
        address[] memory receiverYTs,
        uint256[] memory amountScyToMints
    ) internal returns (uint256[] memory amountPYOuts) {
        amountPYOuts = new uint256[](amountScyToMints.length);

        uint256 index = _pyIndexCurrent();

        for (uint256 i = 0; i < amountScyToMints.length; i++) {
            amountPYOuts[i] = _calcPYToMint(amountScyToMints[i], index);

            _mint(receiverYTs[i], amountPYOuts[i]);
            IPPrincipalToken(PT).mintByYT(receiverPTs[i], amountPYOuts[i]);

            emit Mint(
                msg.sender,
                receiverPTs[i],
                receiverYTs[i],
                amountScyToMints[i],
                amountPYOuts[i]
            );
        }
    }

    function pyIndexStored() public view returns (uint256) {
        return _pyIndexStored;
    }

    function isExpired() public view returns (bool) {
        return MiniHelpers.isCurrentlyExpired(expiry);
    }

    function _redeemPY(address[] memory receivers, uint256[] memory amountPYToRedeems)
        internal
        returns (uint256[] memory amountScyOuts)
    {
        uint256 totalAmountPYToRedeem = amountPYToRedeems.sum();
        IPPrincipalToken(PT).burnByYT(address(this), totalAmountPYToRedeem);
        if (!isExpired()) _burn(address(this), totalAmountPYToRedeem);

        uint256 index = _pyIndexCurrent();
        uint256 totalScyInterestPostExpiry;
        amountScyOuts = new uint256[](receivers.length);

        for (uint256 i = 0; i < receivers.length; i++) {
            uint256 scyInterestPostExpiry;
            (amountScyOuts[i], scyInterestPostExpiry) = _calcScyRedeemableFromPY(
                amountPYToRedeems[i],
                index
            );
            _transferOut(SCY, receivers[i], amountScyOuts[i]);
            totalScyInterestPostExpiry += scyInterestPostExpiry;

            emit Burn(msg.sender, receivers[i], amountPYToRedeems[i], amountScyOuts[i]);
        }
        if (totalScyInterestPostExpiry != 0) {
            postExpiry.totalScyInterestForTreasury += totalScyInterestPostExpiry.Uint128();
        }
    }

    function _calcPYToMint(uint256 amountScy, uint256 indexCurrent)
        internal
        pure
        returns (uint256 amountPY)
    {
        // doesn't matter before or after expiry, since mintPY is only allowed before expiry
        return SCYUtils.scyToAsset(indexCurrent, amountScy);
    }

    function _calcScyRedeemableFromPY(uint256 amountPY, uint256 indexCurrent)
        internal
        view
        returns (uint256 scyToUser, uint256 scyInterestPostExpiry)
    {
        scyToUser = SCYUtils.assetToScy(indexCurrent, amountPY);
        if (isExpired()) {
            uint256 totalScyRedeemable = SCYUtils.assetToScy(postExpiry.firstPYIndex, amountPY);
            scyInterestPostExpiry = totalScyRedeemable - scyToUser;
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
        if (amount == 0) revert Errors.YCNoFloatingScy();
    }

    function _setPostExpiryData() internal {
        PostExpiryData storage local = postExpiry;
        if (local.firstPYIndex != 0) return; // already set

        _redeemExternalReward(); // do a final redeem. All the future reward income will belong to the treasury

        local.firstPYIndex = _pyIndexCurrent().Uint128();
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
        if (isExpired()) index = postExpiry.firstPYIndex;
        else index = _pyIndexCurrent();
    }

    function _pyIndexCurrent() internal returns (uint256 currentIndex) {
        currentIndex = Math.max(ISuperComposableYield(SCY).exchangeRate(), _pyIndexStored);
        _pyIndexStored = currentIndex.Uint128();
        emit NewInterestIndex(currentIndex);
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
            rewardAmounts = __doTransferOutRewardsLocal(tokens, user, receiver, false);
        } else {
            rewardAmounts = __doTransferOutRewardsLocal(tokens, user, receiver, true);
        }
    }

    function __doTransferOutRewardsLocal(
        address[] memory tokens,
        address user,
        address receiver,
        bool allowedToRedeemExternalReward
    ) internal returns (uint256[] memory rewardAmounts) {
        address treasury = IPYieldContractFactory(factory).treasury();
        uint256 feeRate = IPYieldContractFactory(factory).rewardFeeRate();
        bool redeemExternalThisRound;

        rewardAmounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 rewardPreFee = userReward[tokens[i]][user].accrued;
            userReward[tokens[i]][user].accrued = 0;

            uint256 feeAmount = rewardPreFee.mulDown(feeRate);
            rewardAmounts[i] = rewardPreFee - feeAmount;

            if (!redeemExternalThisRound && allowedToRedeemExternalReward) {
                if (_selfBalance(tokens[i]) < rewardPreFee) {
                    _redeemExternalReward();
                    redeemExternalThisRound = true;
                }
            }

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
        if (isExpired()) _setPostExpiryData();
        _updateAndDistributeRewardsForTwo(from, to);
        _distributeInterestForTwo(from, to);
    }
}
