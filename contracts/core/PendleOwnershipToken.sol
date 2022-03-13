// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./base/PendleBaseToken.sol";
import "../interfaces/IPOwnershipToken.sol";

contract PendleOwnershipToken is PendleBaseToken, IPOwnershipToken {
    address public immutable LYT;
    address public YT;

    modifier onlyYT() {
        require(msg.sender == address(YT), "ONLY_YT");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "ONLY_FACTORY");
        _;
    }

    constructor(
        address _LYT,
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 _expiry
    ) PendleBaseToken(_name, _symbol, __decimals, _expiry) {
        LYT = _LYT;
    }

    function initialize(address _YT) external onlyFactory {
        YT = _YT;
    }

    function burnByYT(address user, uint256 amount) external onlyYT {
        _burn(user, amount);
        emit Burn(user, amount);
    }

    function mintByYT(address user, uint256 amount) external onlyYT {
        _mint(user, amount);
        emit Mint(user, amount);
    }
}
