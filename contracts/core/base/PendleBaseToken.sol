// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";
import "../../interfaces/IPBaseToken.sol";

abstract contract PendleBaseToken is ERC20, IPBaseToken {
    uint8 private immutable _decimals;

    uint256 public immutable timeCreated;
    uint256 public immutable expiry;
    address public immutable factory;

    event Burn(address indexed user, uint256 amount);

    event Mint(address indexed user, uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 _expiry
    ) ERC20(_name, _symbol) {
        require(_expiry > block.timestamp, "INVALID_EXPIRY");
        _decimals = __decimals;
        timeCreated = block.timestamp;
        expiry = _expiry;
        factory = msg.sender;
    }

    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return _decimals;
    }

    function isExpired() public view virtual returns (bool res) {
        res = (block.timestamp > expiry);
    }
}
