// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {IPStaticQuoter} from "../interfaces/IPStaticQuoter.sol";
import {PMath} from "../core/libraries/math/PMath.sol";
import {BoringOwnableUpgradeableV2} from "../core/libraries/BoringOwnableUpgradeableV2.sol";

contract StaticStableQuoter is IPStaticQuoter, BoringOwnableUpgradeableV2 {
    using PMath for uint256;

    event WeiUSDPriceSet(uint256 chainId, address indexed token, uint256 wad);

    /// example: for USDC with 6 decimals, _weiUSDPrice[USDC] = 1e12
    mapping(uint256 chainId => mapping(address token => uint256 wad)) internal _weiUSDPrice;

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner) external initializer {
        __BoringOwnableV2_init(owner);
    }

    function weiUSDPrice(uint256 chainId, address token) public view returns (uint256 res) {
        res = _weiUSDPrice[chainId][token];
        require(res != 0, "StaticStableQuoter: token not supported");
    }

    function quote(
        uint256 chainIdIn,
        address tokenIn,
        uint256 amountIn,
        uint256 chainIdOut,
        address tokenOut,
        uint256 slippage
    ) external view returns (uint256 minAmountOut) {
        return (amountIn * weiUSDPrice(chainIdIn, tokenIn) / weiUSDPrice(chainIdOut, tokenOut)).tweakDown(slippage);
    }

    /// ========== Admin functions ==========

    function setWeiUSDPrice(uint256 chainId, address token, uint256 wad) external onlyOwner {
        _weiUSDPrice[chainId][token] = wad;
        emit WeiUSDPriceSet(chainId, token, wad);
    }
}
