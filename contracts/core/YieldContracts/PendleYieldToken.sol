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

/*
With YT yielding more SCYs overtime, which is allowed to be redeemed by users, the reward distribution should
be based on the amount of SCYs that their YT currently represent, plus with their dueInterest.

It has been proven and tested that totalScyRedeemable will not change over time, unless users redeem their interest or redeemPY.

Due to this, it is required to update users' accruedReward STRICTLY BEFORE redeeming their interest.
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

    struct AfterExpiryData {
        bool isFinalized;
        uint128 firstScyIndex;
        uint256[] firstRewardIndexes;
    }

    address public immutable SCY;
    address public immutable PT;
    address public immutable factory;
    uint256 public immutable expiry;

    uint128 public scyReserve;
    uint128 internal _scyIndexStored;

    AfterExpiryData public afterExpiry;

    modifier updateScyReserve() {
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
        updateScyReserve
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
        updateScyReserve
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
    function redeemPY(address[] memory receivers, uint256[] memory maxAmountScyOuts)
        external
        nonReentrant
        updateScyReserve
        returns (uint256 totalAmountScyOut)
    {
        (totalAmountScyOut, ) = _redeemPY(receivers, maxAmountScyOuts);
    }

    /**
     * @dev _updateAndDistributeRewards must be called before every distributeInterest
     */
    function redeemDueInterestAndRewards(address user)
        external
        nonReentrant
        updateScyReserve
        returns (uint256 interestOut, uint256[] memory rewardsOut)
    {
        _updateAndDistributeRewards(user);
        _distributeInterest(user);
        rewardsOut = _doTransferOutRewards(user, user);
        interestOut = _doTransferOutInterest(user, SCY, factory);

        emit RedeemRewards(user, rewardsOut);
        emit RedeemInterest(user, interestOut);
    }

    /**
     * @dev as mentioned in doc, _updateAndDistributeRewards should be placed strictly before every _distributeInterest
     */
    function redeemDueInterest(address user)
        external
        nonReentrant
        updateScyReserve
        returns (uint256 interestOut)
    {
        _updateAndDistributeRewards(user); /// strictly required, see above for explanation
        _distributeInterest(user);

        interestOut = _doTransferOutInterest(user, SCY, factory);

        emit RedeemInterest(user, interestOut);
    }

    /// @dev no updateScyReserve since this function doesn't change the SCY reserve
    function redeemDueRewards(address user)
        external
        nonReentrant
        returns (uint256[] memory rewardsOut)
    {
        _updateAndDistributeRewards(user);
        rewardsOut = _doTransferOutRewards(user, user);
        emit RedeemRewards(user, rewardsOut);
    }

    /// @dev this function will only redeem rewards to the treasury, hence
    /// no need to guard it with onlyGovernance
    /// @dev no updateScyReserve since this function doesn't change the SCY reserve
    function redeemRewardsAfterExpiryForTreasury()
        external
        nonReentrant
        returns (uint256[] memory rewardsOut)
    {
        require(isExpired(), "not expired");
        address[] memory rewardTokens = _getRewardTokens();
        uint256[] memory preBalances = _selfBalances(rewardTokens);

        _redeemExternalReward();

        rewardsOut = _selfBalances(rewardTokens).sub(preBalances);
        _transferOut(rewardTokens, IPYieldContractFactory(factory).treasury(), rewardsOut);
    }

    /// @notice can be called by anyone to lock in all the indexes
    function finalizeAfterExpiryData() public {
        if (!isExpired() || afterExpiry.isFinalized) return;
        afterExpiry.isFinalized = true;
        afterExpiry.firstScyIndex = scyIndexCurrent().Uint128();
        (, afterExpiry.firstRewardIndexes) = _updateRewardIndex();
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
        if (isExpired()) {
            finalizeAfterExpiryData();
            uint256 totalScyRedeemable = SCYUtils.assetToScy(afterExpiry.firstScyIndex, amountPY);
            scyToUser = SCYUtils.assetToScy(scyIndexCurrent(), amountPY);
            scyInterestAfterExpiry = totalScyRedeemable - scyToUser;
        } else {
            scyToUser = SCYUtils.assetToScy(scyIndexCurrent(), amountPY);
        }
    }

    function _getAmountPYToRedeem() internal view returns (uint256) {
        if (!isExpired())
            return Math.min(IERC20(PT).balanceOf(address(this)), balanceOf(address(this)));
        else return IERC20(PT).balanceOf(address(this));
    }

    function _updateScyReserve() internal virtual {
        scyReserve = IERC20(SCY).balanceOf(address(this)).Uint128();
    }

    function _getFloatingScyAmount() internal view returns (uint256 amount) {
        amount = IERC20(SCY).balanceOf(address(this)) - scyReserve;
        require(amount > 0, "RECEIVE_ZERO");
    }

    /*///////////////////////////////////////////////////////////////
                               INTEREST-RELATED
    //////////////////////////////////////////////////////////////*/

    function _getInterestIndex() internal virtual override returns (uint256 index) {
        if (isExpired()) {
            finalizeAfterExpiryData();
            index = afterExpiry.firstScyIndex;
        } else {
            index = scyIndexCurrent();
        }
    }

    function _YTbalance(address user) internal view override returns (uint256) {
        return balanceOf(user);
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    function _doTransferOutRewards(address user, address receiver)
        internal
        virtual
        override
        returns (uint256[] memory rewardAmounts)
    {
        _redeemExternalReward();

        address[] memory tokens = _getRewardTokens();
        rewardAmounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            rewardAmounts[i] = userReward[tokens[i]][user].accrued;
            if (rewardAmounts[i] != 0) {
                userReward[tokens[i]][user].accrued = 0;
                _transferOut(tokens[i], receiver, rewardAmounts[i]);
            }
        }
    }

    function getRewardTokens() external view returns (address[] memory) {
        return _getRewardTokens();
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

    function _rewardSharesTotal() internal view virtual override returns (uint256) {
        return scyReserve;
    }

    function _getRewardTokens() internal view override returns (address[] memory) {
        return ISuperComposableYield(SCY).getRewardTokens();
    }

    function _updateRewardIndex()
        internal
        override
        returns (address[] memory tokens, uint256[] memory indexes)
    {
        tokens = _getRewardTokens();
        if (isExpired()) {
            finalizeAfterExpiryData();
            // padding to handle the very extreme case of SCY adding reward tokens after expiry
            indexes = afterExpiry.firstRewardIndexes.padZeroRight(tokens.length);
        } else {
            indexes = rewardIndexesCurrent();
        }
    }

    function rewardIndexesCurrent() public override returns (uint256[] memory) {
        return ISuperComposableYield(SCY).rewardIndexesCurrent();
    }

    //solhint-disable-next-line ordering
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        _distributeInterestForTwo(from, to);
        _updateAndDistributeRewardsForTwo(from, to);
    }
}
