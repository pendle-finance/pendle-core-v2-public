// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../PendleERC4626SY.sol";
import "../../../../interfaces/IERC4626.sol";

contract PendleGTokenSY is PendleERC4626SY {
    constructor(
        string memory _name,
        string memory _symbol,
        address _erc4626
    ) PendleERC4626SY(_name, _symbol, _erc4626) {}

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](1);
        res[0] = yieldToken;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == yieldToken;
    }

    function exchangeRate() public view virtual override returns (uint256) {
        return IERC4626(yieldToken).convertToAssets(1e18);
    }
}
