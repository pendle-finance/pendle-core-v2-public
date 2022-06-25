// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../interfaces/ISuperComposableYield.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPPrincipalToken.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../libraries/math/Math.sol";
import "../../interfaces/IPYieldContractFactory.sol";
import "../../libraries/SCY/SCYUtils.sol";
import "../../libraries/helpers/MiniHelpers.sol";

import "../PendleERC20.sol";
import "../../libraries/RewardManagerMini.sol";

/*
With YT yielding more SCYs overtime, which is allowed to be redeemed by users, the reward distribution should
be based on the amount of SCYs that their YT currently represent, plus with their dueInterest.

It has been proven and tested that totalScyRedeemable will not change over time, unless users redeem their interest or redeemPY.

Due to this, it is required to update users' accruedReward STRICTLY BEFORE redeeming their interest.
*/
contract PendleYieldToken is IPYieldToken, PendleERC20, RewardManagerMini {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using ArrayLib for uint256[];

    struct UserInterest {
        uint128 index;
        uint128 accrued;
    }

    struct InterestState {
        uint128 lastIndexBeforeExpiry;
        uint128 scyReserve;
    }

    address public immutable SCY;
    address public immutable PT;
    address public immutable factory;
    uint256 public immutable expiry;

    InterestState public interestState;
    mapping(address => UserInterest) public userInterest;

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
    ) PendleERC20(_name, _symbol, __decimals) {
        require(_SCY != address(0) && _PT != address(0), "zero address");
        SCY = _SCY;
        PT = _PT;
        expiry = _expiry;
        factory = msg.sender;
    }

    /**
     * @notice this function splits scy into PT + YT of equal qty
     * @dev the scy to tokenize has to be pre-transferred to this contract prior to the function call
     */
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

    function redeemPY(address[] memory receivers, uint256[] memory amounts)
        external
        nonReentrant
        updateScyReserve
        returns (uint256 amountScyOut)
    {
        (amountScyOut, ) = _redeemPY(receivers, amounts);
    }

    /**
     * @dev as mentioned in doc, updateDueReward should be placed strictly before every redeemDueInterest
     */
    function redeemDueInterestAndRewards(address user)
        external
        nonReentrant
        updateScyReserve
        returns (uint256 interestOut, uint256[] memory rewardsOut)
    {
        // redeemDueRewards before redeemDueInterest
        _distributeUserRewards(user);
        _distributeUserInterest(user);
        rewardsOut = _doTransferOutRewards(user, user);
        interestOut = _doTransferOutInterest(user);

        emit RedeemRewards(user, rewardsOut);
        emit RedeemInterest(user, interestOut);
    }

    /**
     * @dev as mentioned in doc, _distributeUserRewards should be placed strictly before every _distributeUserInterest
     */
    function redeemDueInterest(address user)
        external
        nonReentrant
        updateScyReserve
        returns (uint256 interestOut)
    {
        _distributeUserRewards(user); /// strictly required, see above for explanation
        _distributeUserInterest(user);

        interestOut = _doTransferOutInterest(user);

        emit RedeemInterest(user, interestOut);
    }

    /// @dev no updateScyReserve since this function doesn't change the SCY reserve
    function redeemDueRewards(address user)
        external
        nonReentrant
        returns (uint256[] memory rewardsOut)
    {
        _distributeUserRewards(user);

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

    /// @dev no updateScyReserve since this function doesn't change the SCY reserve
    function updateAndDistributeReward(address user) external nonReentrant {
        _distributeUserRewards(user);
    }

    /// @dev no updateScyReserve since this function doesn't change the SCY reserve
    function updateAndDistributeInterest(address user) external nonReentrant {
        _distributeUserInterest(user);
    }

    function getRewardTokens() external view returns (address[] memory) {
        return _getRewardTokens();
    }

    /// @dev no reentrant & updateScyReserve since this function updates just the lastIndex
    function updateAndGetScyIndex()
        public
        returns (uint256 currentIndex, uint256 lastIndexBeforeExpiry)
    {
        currentIndex = ISuperComposableYield(SCY).exchangeRate();
        if (isExpired()) {
            lastIndexBeforeExpiry = interestState.lastIndexBeforeExpiry;
        } else {
            lastIndexBeforeExpiry = currentIndex;
            interestState.lastIndexBeforeExpiry = lastIndexBeforeExpiry.Uint128();
        }
    }

    function isExpired() public view returns (bool) {
        return MiniHelpers.isCurrentlyExpired(expiry);
    }

    function _redeemPY(address[] memory receivers, uint256[] memory maxScyAmounts)
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

        _transferOutMaxMulti(SCY, totalScyToReceivers, receivers, maxScyAmounts);
    }

    function _distributeUserInterest(address user) internal {
        uint256 prevIndex = userInterest[user].index;

        (, uint256 currentIndexBeforeExpiry) = updateAndGetScyIndex();

        if (prevIndex == currentIndexBeforeExpiry) return;
        if (prevIndex == 0) {
            userInterest[user].index = currentIndexBeforeExpiry.Uint128();
            return;
        }

        uint256 principal = balanceOf(user);

        uint256 interestFromYT = (principal * (currentIndexBeforeExpiry - prevIndex)).divDown(
            prevIndex * currentIndexBeforeExpiry
        );

        userInterest[user].accrued += interestFromYT.Uint128();
        userInterest[user].index = currentIndexBeforeExpiry.Uint128();
    }

    function _doTransferOutInterest(address user) internal returns (uint256 interestOut) {
        uint256 interestPreFee = userInterest[user].accrued;
        userInterest[user].accrued = 0;

        uint256 feeRate = IPYieldContractFactory(factory).interestFeeRate();
        uint256 feeAmount = interestPreFee.mulDown(feeRate);

        IERC20(SCY).safeTransfer(IPYieldContractFactory(factory).treasury(), feeAmount);

        interestOut = interestPreFee - feeAmount;
        IERC20(SCY).safeTransfer(user, interestOut);
    }

    function _calcPYToMint(uint256 amountScy) internal returns (uint256 amountPY) {
        (, uint256 lastIndexBeforeExpiry) = updateAndGetScyIndex();
        return SCYUtils.scyToAsset(lastIndexBeforeExpiry, amountScy);
    }

    function _calcScyRedeemableFromPY(uint256 amountPY)
        internal
        returns (uint256 scyToUser, uint256 scyInterestAfterExpiry)
    {
        (uint256 currentIndex, uint256 lastIndexBeforeExpiry) = updateAndGetScyIndex();
        uint256 totalScyRedeemable = SCYUtils.assetToScy(lastIndexBeforeExpiry, amountPY);
        scyToUser = SCYUtils.assetToScy(currentIndex, amountPY);
        scyInterestAfterExpiry = totalScyRedeemable - scyToUser;
    }

    /// @notice returns the total SCY redeemable for an user, including the user's accrued interest
    function _getTotalScyRedeemable(address user) internal view returns (uint256) {
        uint256 scyIndex = userInterest[user].index;
        if (scyIndex == 0) return 0;
        return SCYUtils.assetToScy(scyIndex, balanceOf(user)) + userInterest[user].accrued;
    }

    function _getAmountPYToRedeem() internal view returns (uint256) {
        if (!isExpired())
            return Math.min(IERC20(PT).balanceOf(address(this)), balanceOf(address(this)));
        else return IERC20(PT).balanceOf(address(this));
    }

    function _updateScyReserve() internal virtual {
        interestState.scyReserve = IERC20(SCY).balanceOf(address(this)).Uint128();
    }

    function _getFloatingScyAmount() internal view returns (uint256 amount) {
        amount = IERC20(SCY).balanceOf(address(this)) - interestState.scyReserve;
        require(amount > 0, "RECEIVE_ZERO");
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    function _redeemExternalReward() internal virtual override {
        ISuperComposableYield(SCY).claimRewards(address(this)); // ignore return
    }

    function _rewardSharesTotal() internal view virtual override returns (uint256) {
        return interestState.scyReserve;
    }

    function _rewardSharesUser(address user) internal view virtual override returns (uint256) {
        return _getTotalScyRedeemable(user);
    }

    function _getRewardTokens() internal view override returns (address[] memory) {
        return ISuperComposableYield(SCY).getRewardTokens();
    }

    function _getRewardIndexes() internal override returns (uint256[] memory) {
        return ISuperComposableYield(SCY).rewardIndexesCurrent();
    }

    function rewardIndexesCurrent() external override returns (uint256[] memory) {
        return ISuperComposableYield(SCY).rewardIndexesCurrent();
    }

    function rewardIndexesStored() external view override returns (uint256[] memory) {
        return ISuperComposableYield(SCY).rewardIndexesStored();
    }

    //solhint-disable-next-line ordering
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        // Before the change in YT balance, users' totalScyRedeemable is kept unchanged from last time
        // Therefore, both updating due interest before or after due reward work the same.
        if (from != address(0) && from != address(this)) {
            _distributeUserInterest(from);
            _distributeUserRewards(from);
        }
        if (to != address(0) && to != address(this)) {
            _distributeUserInterest(to);
            _distributeUserRewards(to);
        }
    }
}
