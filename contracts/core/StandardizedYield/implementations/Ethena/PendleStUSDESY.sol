// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../PendleERC4626SY.sol";

contract PendleStUSDESY is PendleERC4626SY {
    constructor(address _stusde) PendleERC4626SY("SY Ethena stUSDE", "SY-stUSDE", _stusde) {}

    function getTokensOut() public view override returns (address[] memory res) {
        return ArrayLib.create(yieldToken);
    }

    function isValidTokenOut(address token) public view override returns (bool) {
        return token == yieldToken;
    }
}
