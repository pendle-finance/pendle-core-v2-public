// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface ICamelotNFTHandler is IERC721Receiver {
    function onNFTHarvest(
        address operator,
        address to,
        uint256 tokenId,
        uint256 grailAmount,
        uint256 xGrailAmount
    ) external returns (bool);

    function onNFTAddToPosition(address operator, uint256 tokenId, uint256 lpAmount) external returns (bool);

    function onNFTWithdraw(address operator, uint256 tokenId, uint256 lpAmount) external returns (bool);
}
