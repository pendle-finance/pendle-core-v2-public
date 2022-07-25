pragma solidity 0.8.15;

import "../libraries/VeBalanceLib.sol";

interface IPVotingController {
    event AddPool(uint64 indexed chainId, address indexed pool);

    event RemovePool(uint64 indexed chainId, address indexed pool);

    event Unvote(address indexed user, address indexed pool, VeBalance vote);

    event Vote(address indexed user, address indexed pool, uint64 weight, VeBalance vote);

    event SetPendlePerSec(uint256 newPendlePerSec);

    event BroadcastResults(
        uint64 indexed chainId,
        uint128 indexed wTime,
        uint128 totalPendlePerSec
    );
}
