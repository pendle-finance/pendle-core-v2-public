// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../../../interfaces/Solv/ISolvRouter.sol";
import "../../../../interfaces/Solv/ISolvOpenFundMarket.sol";
import "../../../../interfaces/Solv/ISolvOracle.sol";
import "../../../../interfaces/Solv/ISolvERC3525.sol";

library PendleSolvHelperBSC {
    address public constant SOLV_BTCBBN_ROUTER = 0x8EC6Ef69a423045cEa97d2Bd0D768D042A130aA7;
    address public constant SOLV_BTCBBN_TOKEN = 0x1346b618dC92810EC74163e4c27004c921D446a5;
    bytes32 public constant SOLV_BTCBBN_POOLID = 0x6fe7f2753798616f555389f971dae58b32e181fab8b1d60d35e5ddafbb6bb5b7;

    address public constant SOLV_BTC_ROUTER = 0x5c1215712F174dF2Cbc653eDce8B53FA4CAF2201;
    address public constant SOLV_BTC_TOKEN = 0x4aae823a6a0b376De6A78e74eCC5b079d38cBCf7;
    bytes32 public constant SOLV_BTC_POOLID = 0xafb1107b43875eb79f72e3e896933d4f96707451c3d5c32741e8e05410b321d8;

    address public constant WBTC = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;

    address public constant SOLV_OPEN_FUND_MARKET = 0xaE050694c137aD777611286C316E5FDda58242F3;

    function _mintBTCBBN(address tokenIn, uint256 amountIn) internal returns (uint256) {
        assert(tokenIn == WBTC || tokenIn == SOLV_BTC_TOKEN);

        if (tokenIn == WBTC) {
            amountIn = ISolvRouter(SOLV_BTC_ROUTER).createSubscription(SOLV_BTC_POOLID, amountIn);
        }
        return ISolvRouter(SOLV_BTCBBN_ROUTER).createSubscription(SOLV_BTCBBN_POOLID, amountIn);
    }

    function _previewMintBTCBBN(address tokenIn, uint256 amountIn) internal view returns (uint256) {
        assert(tokenIn == WBTC || tokenIn == SOLV_BTC_TOKEN);

        if (tokenIn == WBTC) {
            amountIn = _convertToShare(WBTC, amountIn);
        }
        return _convertToShare(SOLV_BTC_TOKEN, amountIn);
    }

    function _convertToShare(address tokenIn, uint256 amountIn) internal view returns (uint256) {
        bytes32 poolId = tokenIn == WBTC ? SOLV_BTC_POOLID : SOLV_BTCBBN_POOLID;
        ISolvOpenFundMarket.PoolInfo memory info = ISolvOpenFundMarket(SOLV_OPEN_FUND_MARKET).poolInfos(poolId);
        uint256 numerator = 10 ** ISolvERC3525(info.poolSFTInfo.openFundShare).valueDecimals();
        (uint256 price, ) = ISolvOracle(info.navOracle).getSubscribeNav(poolId, block.timestamp);
        return (amountIn * numerator) / price;
    }
}
