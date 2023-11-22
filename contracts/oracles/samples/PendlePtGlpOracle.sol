// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../PendlePtOracleLib.sol";
import "../../interfaces/IPPtOracle.sol";
import "../../interfaces/GMX/IGlpManager.sol";
import "../../core/libraries/math/PMath.sol";

/**
 * @notice The returned price from this contract is multiply with the USD price of GLP read from
 * GLPManager contract
 *
 * @dev This contract uses the PendlePtOracleLibrary to get the price instead of calling PendlePtOracle contract
 * to save 1 external call gas consumption
 */
contract PendlePtGlpOracle {
    using PendlePtOracleLib for IPMarket;

    uint32 public immutable twapDuration;
    address public immutable market;
    address public immutable glpManager;
    error OracleNotReady(bool increaseCardinalityRequired, bool oldestObservationSatisfied);

    constructor(address _ptOracle, uint32 _twapDuration, address _market, address _glpManager) {
        twapDuration = _twapDuration;
        market = _market;
        glpManager = _glpManager;

        (bool increaseCardinalityRequired, , bool oldestObservationSatisfied) = IPPtOracle(_ptOracle).getOracleState(
            market,
            twapDuration
        );

        if (increaseCardinalityRequired || !oldestObservationSatisfied) {
            revert OracleNotReady(increaseCardinalityRequired, oldestObservationSatisfied);
        }
    }

    function getPtPrice() external view virtual returns (uint256) {
        // using library directly to save 1 external call (gas optimization)
        uint256 ptRate = IPMarket(market).getPtToAssetRate(twapDuration);
        uint256 assetPrice = IGlpManager(glpManager).getPrice(true);
        return (assetPrice * ptRate) / (10 ** 30);
    }

    function decimals() external pure virtual returns (uint8) {
        return 18;
    }
}
