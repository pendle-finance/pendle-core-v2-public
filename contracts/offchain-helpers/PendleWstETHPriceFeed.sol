// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../interfaces/IWstETH.sol";
import "../interfaces/IPPriceFeed.sol";
import {AggregatorV2V3Interface as IChainlinkAggregator} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

contract PendleWstETHPriceFeed is IPPriceFeed {
    // solhint-disable immutable-vars-naming
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant STETH_TO_ETH = 0x86392dC19c0b719886221c78AB11eb8Cf5c52812;
    address public constant ETH_TO_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    uint256 public constant FEED_MULTIPLIER = 10 ** 8;

    function getPrice() external view returns (uint256) {
        uint256 toStETH = IWstETH(WSTETH).stEthPerToken();
        uint256 toETH = _applyFeedMultiplier(toStETH, STETH_TO_ETH);
        return _applyFeedMultiplier(toETH, ETH_TO_USD);
    }

    function _applyFeedMultiplier(uint256 base, address feed) internal view returns (uint256) {
        return
            (base * uint256(IChainlinkAggregator(feed).latestAnswer())) / 10 ** (IChainlinkAggregator(feed).decimals());
    }
}
