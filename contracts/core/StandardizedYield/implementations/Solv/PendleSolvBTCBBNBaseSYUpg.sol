// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../SYBaseUpg.sol";
import "./PendleSolvHelperBase.sol";
import "../../../../interfaces/IPExchangeRateOracle.sol";

contract PendleSolvBTCBBNBaseSYUpg is SYBaseUpg {
    event SetNewExchangeRateOracle(address oracle);

    address public constant CBBTC = PendleSolvHelperBase.CBBTC;
    address public constant SOLV_BTC = PendleSolvHelperBase.SOLV_BTC_TOKEN;
    address public constant SOLV_BTCBBN = PendleSolvHelperBase.SOLV_BTCBBN_TOKEN;

    address public exchangeRateOracle;

    constructor() SYBaseUpg(SOLV_BTCBBN) {}

    function initialize(address _initialExchangeRateOracle) external initializer {
        __SYBaseUpg_init("SY SolvBTC Babylon", "SY-SolvBTC.BBN");
        _setExchangeRateOracle(_initialExchangeRateOracle);
        _safeApproveInf(CBBTC, PendleSolvHelperBase.SOLV_BTC_ROUTER);
        _safeApproveInf(SOLV_BTC, PendleSolvHelperBase.SOLV_BTCBBN_ROUTER);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address tokenIn, uint256 amountDeposited) internal virtual override returns (uint256) {
        if (tokenIn == SOLV_BTCBBN) {
            return amountDeposited;
        }
        return PendleSolvHelperBase._mintBTCBBN(tokenIn, amountDeposited);
    }

    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256) {
        _transferOut(SOLV_BTCBBN, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return IPExchangeRateOracle(exchangeRateOracle).getExchangeRate();
    }

    function setExchangeRateOracle(address newOracle) external virtual onlyOwner {
        _setExchangeRateOracle(newOracle);
    }

    function _setExchangeRateOracle(address newOracle) internal virtual {
        exchangeRateOracle = newOracle;
        emit SetNewExchangeRateOracle(newOracle);
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == SOLV_BTCBBN) {
            return amountTokenToDeposit;
        }
        return PendleSolvHelperBase._previewMintBTCBBN(tokenIn, amountTokenToDeposit);
    }

    function _previewRedeem(
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal view virtual override returns (uint256 amountTokenOut) {
        return amountSharesToRedeem;
    }

    function getTokensIn() public view virtual override returns (address[] memory) {
        return ArrayLib.create(CBBTC, SOLV_BTC, SOLV_BTCBBN);
    }

    function getTokensOut() public view virtual override returns (address[] memory) {
        return ArrayLib.create(SOLV_BTCBBN);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == CBBTC || token == SOLV_BTC || token == SOLV_BTCBBN;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == SOLV_BTCBBN;
    }

    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, CBBTC, IERC20Metadata(CBBTC).decimals());
    }
}
