// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ICamelotNitroPool is IERC721 {
    function withdraw(uint256 tokenId) external;

    function grailToken() external view returns (address);

    function xGrailToken() external view returns (address);

    function nftPool() external view returns (address);

    function harvest() external;
}