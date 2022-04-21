// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./PendleBaseToken.sol";
import "../interfaces/IPOwnershipToken.sol";
import "../interfaces/IPYieldToken.sol";

contract PendleOwnershipToken is PendleBaseToken, IPOwnershipToken {
    address public immutable SCY;
    address public YT;

    event YTSet(address indexed YT);

    modifier onlyYT() {
        require(msg.sender == address(YT), "ONLY_YT");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "ONLY_FACTORY");
        _;
    }

    constructor(
        address _SCY,
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 _expiry
    ) PendleBaseToken(_name, _symbol, __decimals, _expiry) {
        require(_SCY != address(0), "zero address");
        SCY = _SCY;
    }

    function initialize(address _YT) external onlyFactory {
        require(IPYieldToken(_YT).OT() == address(this), "invalid YT");
        YT = _YT;
        emit YTSet(_YT);
    }

    function burnByYT(address user, uint256 amount) external onlyYT {
        _burn(user, amount);
    }

    function mintByYT(address user, uint256 amount) external onlyYT {
        _mint(user, amount);
    }
}
