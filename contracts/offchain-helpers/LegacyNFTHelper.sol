// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

contract LegacyNFTHelper {
    address private constant ADDR = 0x9B1Bfa5D13375e8E21FDCb0A5F965974f9DcfDd1;

    function getNumOwned(address user) public view returns (uint256) {
        uint256 starCount = StarNFTV1(ADDR).starCount();
        uint256 numOwned = 0;
        for (uint256 i = 0; i < starCount; i++) {
            if (StarNFTV1(ADDR).isOwnerOf(user, i)) {
                numOwned++;
            }
        }
        return numOwned;
    }
}

interface StarNFTV1 {
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event URI(string value, uint256 indexed id);

    function addMinter(address minter) external;

    function balanceOf(address account, uint256 id) external view returns (uint256);

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) external view returns (uint256[] memory);

    function baseURI() external view returns (string memory);

    function burn(address account, uint256 id) external;

    function burnBatch(address account, uint256[] memory ids) external;

    function isApprovedForAll(address account, address operator) external view returns (bool);

    function isOwnerOf(address account, uint256 id) external view returns (bool);

    function mint(address account, uint256 powah) external returns (uint256);

    function mintBatch(address account, uint256 amount, uint256[] memory powahArr) external returns (uint256[] memory);

    function minters(address) external view returns (bool);

    function owner() external view returns (address);

    function removeMinter(address minter) external;

    function renounceOwnership() external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;

    function setApprovalForAll(address operator, bool approved) external;

    function setURI(string memory newURI) external;

    function starCount() external view returns (uint256);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function transferOwnership(address newOwner) external;

    function uri(uint256 id) external view returns (string memory);
}
