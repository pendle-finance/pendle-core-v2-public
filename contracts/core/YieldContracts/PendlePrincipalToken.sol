// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../interfaces/IPPrincipalToken.sol";
import "../../interfaces/IPYieldToken.sol";

import "../PendleERC20.sol";

contract PendlePrincipalToken is PendleERC20, IPPrincipalToken {
    address public immutable SCY;
    address public immutable YT;
    address public immutable factory;
    uint256 public immutable expiry;

    modifier onlyYT() {
        require(msg.sender == address(YT), "ONLY_YT");
        _;
    }

    constructor(
        address _SCY,
        address _YT,
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 _expiry
    ) PendleERC20(_name, _symbol, __decimals) {
        SCY = _SCY;
        YT = _YT;
        expiry = _expiry;
        factory = msg.sender;
    }

    /**
     * @dev only callable by the YT correspond to this PT
     */
    function burnByYT(address user, uint256 amount) external onlyYT {
        _burn(user, amount);
    }

    /**
     * @dev only callable by the YT correspond to this PT
     */
    function mintByYT(address user, uint256 amount) external onlyYT {
        _mint(user, amount);
    }
}
