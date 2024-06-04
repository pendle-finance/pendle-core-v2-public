// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../PendleLpOracleLib.sol";
import "../../interfaces/IPPYLpOracle.sol";
import "../../interfaces/GMX/IGlpManager.sol";
import "../../core/libraries/math/PMath.sol";

/**
 * @notice The LP/GLP price gotten from the market using the LpOracleLib is multiplied with the USD price of GLP read from
 * GLPManager contract
 */
contract BoringLpGlpOracle {
    using PendleLpOracleLib for IPMarket;

    uint32 public immutable twapDuration;
    address public immutable market;
    address public immutable glpManager;
    error OracleNotReady(bool increaseCardinalityRequired, bool oldestObservationSatisfied);

    constructor(address _ptOracle, uint32 _twapDuration, address _market, address _glpManager) {
        twapDuration = _twapDuration;
        market = _market;
        glpManager = _glpManager;

        (bool increaseCardinalityRequired, , bool oldestObservationSatisfied) = IPPYLpOracle(_ptOracle).getOracleState(
            market,
            twapDuration
        );

        if (increaseCardinalityRequired || !oldestObservationSatisfied) {
            revert OracleNotReady(increaseCardinalityRequired, oldestObservationSatisfied);
        }
    }

    function getLpPrice() external view virtual returns (uint256) {
        uint256 lpRate = IPMarket(market).getLpToAssetRate(twapDuration);
        uint256 assetPrice = IGlpManager(glpManager).getPrice(true);
        return (assetPrice * lpRate) / (10 ** 30);
    }

    function decimals() external pure virtual returns (uint8) {
        return 18;
    }
}
