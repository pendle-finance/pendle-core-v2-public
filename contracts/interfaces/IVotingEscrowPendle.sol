pragma solidity 0.8.9;
pragma abicoder v2;

import "./IVePToken.sol";

interface IVotingEscrowPendle is IVePToken {
    // ============= ACTIONS =============

    function lock(uint256 expiry) external returns (uint256);

    function increaseLockAmount(address receiver) external returns (uint256);

    function increaseLockDuration(uint256 duration) external returns (uint256);

    function withdraw(address user) external returns (uint256);

    /**
     * @return amount :amount of vePendle voted for pool
     */
    function vote(address gauge, uint256 weight) external returns (uint256 amount);

    // ============= USER INFO =============

    /**
     * @return lockedAmount :amount of PENDLE user locked
     * @return expiry :expiry of users' locked PENDLE
     */
    function readUserInfo(address user)
        external
        view
        returns (uint256 lockedAmount, uint256 expiry);
}
