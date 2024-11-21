// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../../../interfaces/Solv/ISolvRouter.sol";
import "../../../../interfaces/Solv/ISolvOpenFundMarket.sol";
import "../../../../interfaces/Solv/ISolvOracle.sol";
import "../../../../interfaces/Solv/ISolvERC3525.sol";

library PendleSolvHelperBase {
    address public constant SOLV_BTCBBN_ROUTER = 0x814F3ae67dF0da9fe2399a29516FD14b9085263a;
    address public constant SOLV_BTCBBN_TOKEN = 0xC26C9099BD3789107888c35bb41178079B282561;
    bytes32 public constant SOLV_BTCBBN_POOLID = 0xb20032ac848893cf4820a7b3259020ffd5057d49f537c2adc5f74a337cc56ddc;

    address public constant SOLV_BTC_ROUTER = 0x65EFfDA5e69dF470d4dBd31a805e15855Cae65c7;
    address public constant SOLV_BTC_TOKEN = 0x3B86Ad95859b6AB773f55f8d94B4b9d443EE931f;
    bytes32 public constant SOLV_BTC_POOLID = 0x0d85d41382f6f2effeaa41a46855870ec8b1577c6c59cf16d72856a22988e3f5;

    address public constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    address public constant SOLV_OPEN_FUND_MARKET = 0xf5a247157656678398B08d3eFa1673358C611A3f;

    function _mintBTCBBN(address tokenIn, uint256 amountIn) internal returns (uint256) {
        assert(tokenIn == CBBTC || tokenIn == SOLV_BTC_TOKEN);

        if (tokenIn == CBBTC) {
            amountIn = ISolvRouter(SOLV_BTC_ROUTER).createSubscription(SOLV_BTC_POOLID, amountIn);
        }
        return ISolvRouter(SOLV_BTCBBN_ROUTER).createSubscription(SOLV_BTCBBN_POOLID, amountIn);
    }

    function _previewMintBTCBBN(address tokenIn, uint256 amountIn) internal view returns (uint256) {
        assert(tokenIn == CBBTC || tokenIn == SOLV_BTC_TOKEN);

        if (tokenIn == CBBTC) {
            amountIn = _convertToShare(CBBTC, amountIn);
        }
        return _convertToShare(SOLV_BTC_TOKEN, amountIn);
    }

    function _convertToShare(address tokenIn, uint256 amountIn) internal view returns (uint256) {
        bytes32 poolId = tokenIn == CBBTC ? SOLV_BTC_POOLID : SOLV_BTCBBN_POOLID;
        ISolvOpenFundMarket.PoolInfo memory info = ISolvOpenFundMarket(SOLV_OPEN_FUND_MARKET).poolInfos(poolId);
        uint256 numerator = 10 ** ISolvERC3525(info.poolSFTInfo.openFundShare).valueDecimals();
        (uint256 price, ) = ISolvOracle(info.navOracle).getSubscribeNav(poolId, block.timestamp);
        return (amountIn * numerator) / price;
    }
}
