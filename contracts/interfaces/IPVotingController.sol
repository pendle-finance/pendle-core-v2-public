pragma solidity 0.8.13;

import "../libraries/VeBalanceLib.sol";

interface IPVotingController {
    event Unvote(address indexed user, address indexed pool, VeBalance vote);

    event Vote(address indexed user, address indexed pool, uint64 weight, VeBalance vote);
}
