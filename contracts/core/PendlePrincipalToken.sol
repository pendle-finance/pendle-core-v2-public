// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.14;

import "./PendleBaseToken.sol";
import "../interfaces/IPPrincipalToken.sol";
import "../interfaces/IPYieldToken.sol";

contract PendlePrincipalToken is PendleBaseToken, IPPrincipalToken {
    address public immutable SCY;
    address public immutable YT;

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
    ) PendleBaseToken(_name, _symbol, __decimals, _expiry) {
        SCY = _SCY;
        YT = _YT;
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
