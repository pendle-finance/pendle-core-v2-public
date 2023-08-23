// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ICamelotNFTPool is IERC721 {
    function createPosition(uint256 amount, uint256 lockDuration) external;

    function lastTokenId() external view returns (uint256);

    function addToPosition(uint256 tokenId, uint256 amountToAdd) external;

    function withdrawFromPosition(uint256 tokenId, uint256 amountToWithdraw) external;

    function harvestPosition(uint256 tokenId) external;

    function yieldBooster() external view returns (address);

    function emergencyWithdraw(uint256 tokenId) external;

    function emergencyUnlock() external view returns (bool);

    function getPoolInfo()
        external
        view
        returns (
            address lpToken,
            address grailToken,
            address xGrailToken,
            uint256 lastRewardTime,
            uint256 accRewardsPerShare,
            uint256 lpSupply,
            uint256 lpSupplyWithMultiplier,
            uint256 allocPoint
        );
}
