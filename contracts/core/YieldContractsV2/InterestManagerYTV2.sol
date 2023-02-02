// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPPrincipalToken.sol";
import "../../interfaces/IPInterestManagerYT.sol";
import "../../interfaces/IPYieldContractFactory.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../libraries/math/Math.sol";
import "../libraries/TokenHelper.sol";
import "../StandardizedYield/SYUtils.sol";

/*
With YT yielding more SYs overtime, which is allowed to be redeemed by users, the reward distribution should
be based on the amount of SYs that their YT currently represent, plus with their dueInterest.

It has been proven and tested that totalSyRedeemable will not change over time, unless users redeem their interest or redeemPY.

Due to this, it is required to update users' accruedReward STRICTLY BEFORE redeeming their interest.
*/
abstract contract InterestManagerYTV2 is TokenHelper, IPInterestManagerYT {
    using Math for uint256;

    struct UserInterest {
        uint128 index;
        uint128 accrued;
    }

    uint256 public globalInterestIndex;
    mapping(address => UserInterest) public userInterest;

    function _distributeInterest(address user) internal {
        _distributeInterestForTwo(user, address(0));
    }

    function _distributeInterestForTwo(address user1, address user2) internal {
        uint256 index = globalInterestIndex;
        if (user1 != address(0) && user1 != address(this))
            _distributeInterestPrivate(user1, index);
        if (user2 != address(0) && user2 != address(this))
            _distributeInterestPrivate(user2, index);
    }

    function _doTransferOutInterest(address user, address SY)
        internal
        returns (uint256 interestAmount)
    {
        interestAmount = userInterest[user].accrued;
        _transferOut(SY, user, interestAmount);
        userInterest[user].accrued = 0;
    }

    // should only be callable from `_distributeInterestForTwo` & make sure user != address(0) && user != address(this)
    function _distributeInterestPrivate(address user, uint256 currentIndex) private {
        assert(user != address(0) && user != address(this));

        uint256 prevIndex = userInterest[user].index;
        // uint256 interestFeeRate = _getInterestFeeRate();

        if (prevIndex == currentIndex) return;
        if (prevIndex == 0) {
            userInterest[user].index = currentIndex.Uint128();
            return;
        }

        userInterest[user].accrued += _YTbalance(user).mulDown(currentIndex - prevIndex).Uint128();
        userInterest[user].index = currentIndex.Uint128();
    }

    function _updateInterestIndex(uint256 syInterestAccrued) internal {
        globalInterestIndex += syInterestAccrued.divDown(_YTSupply());
    }

    function _getInterestIndex() internal virtual returns (uint256 index);

    function _YTbalance(address user) internal view virtual returns (uint256);

    function _YTSupply() internal view virtual returns (uint256);

    function _calcInterest(
        uint256 principal,
        uint256 prevIndex,
        uint256 currentIndex
    ) internal pure returns (uint256) {
        return (principal * (currentIndex - prevIndex)).divDown(prevIndex * currentIndex);
    }
}
