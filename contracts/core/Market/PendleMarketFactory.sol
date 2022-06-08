// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPYieldContractFactory.sol";
import "../../interfaces/IPMarketFactory.sol";

import "../../libraries/helpers/MiniDeployer.sol";
import "../../periphery/PermissionsV2Upg.sol";

import "./PendleMarket.sol";
import "../LiquidityMining/PendleGauge.sol";

contract PendleMarketFactory is PermissionsV2Upg, MiniDeployer, IPMarketFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct MarketConfig {
        address treasury;
        uint96 lnFeeRateRoot;
        // 1 SLOT = 256 bits
        uint32 rateOracleTimeWindow;
        uint8 reserveFeePercent;
        // 1 SLOT = 40 bits
    }

    uint256 private constant MIN_RATE_ORACLE_TIME_WINDOW = 300 seconds;

    address public immutable yieldContractFactory;
    address public immutable marketCreationCodePointer;
    uint256 public immutable maxLnFeeRateRoot;

    // PT -> scalarRoot -> initialAnchor
    mapping(address => mapping(int256 => mapping(int256 => address))) internal markets;
    EnumerableSet.AddressSet internal allMarkets;

    address public vePendle;
    address public gaugeController;

    MarketConfig public marketConfig;

    constructor(
        address _governanceManager,
        address _yieldContractFactory,
        address _treasury,
        uint96 _lnFeeRateRoot,
        uint32 _rateOracleTimeWindow,
        uint8 _reserveFeePercent,
        bytes memory _marketCreationCode
    ) PermissionsV2Upg(_governanceManager) {
        require(_yieldContractFactory != address(0), "zero address");
        yieldContractFactory = _yieldContractFactory;
        maxLnFeeRateRoot = uint256(LogExpMath.ln(int256((105 * Math.IONE) / 100))); // ln(1.05)

        setTreasury(_treasury);
        setlnFeeRateRoot(_lnFeeRateRoot);
        setRateOracleTimeWindow(_rateOracleTimeWindow);
        setReserveFeePercent(_reserveFeePercent);
        marketCreationCodePointer = _setCreationCode(_marketCreationCode);
    }

    /**
     * @notice Create a market between PT and its corresponding SCY
     * with scalar & anchor config. Anyone is allowed to create a market on their own.
     */
    function createNewMarket(
        address PT,
        int256 scalarRoot,
        int256 initialAnchor
    ) external returns (address market) {
        require(IPYieldContractFactory(yieldContractFactory).isPT(PT), "Invalid PT");
        require(vePendle != address(0), "vePendle unset");
        require(gaugeController != address(0), "gaugeController unset");
        require(
            markets[PT][scalarRoot][initialAnchor] == address(0),
            "duplicated creation params"
        );

        market = _deployWithArgs(
            marketCreationCodePointer,
            abi.encode(PT, scalarRoot, initialAnchor, vePendle, gaugeController)
        );

        markets[PT][scalarRoot][initialAnchor] = market;
        require(allMarkets.add(market) == true, "IE market can't be added");

        emit CreateNewMarket(PT, scalarRoot, initialAnchor);
    }

    function isValidMarket(address market) external view returns (bool) {
        return allMarkets.contains(market);
    }

    function treasury() external view returns (address) {
        return marketConfig.treasury;
    }

    function setTreasury(address newTreasury) public onlyGovernance {
        require(newTreasury != address(0), "zero address");
        marketConfig.treasury = newTreasury;
    }

    function setlnFeeRateRoot(uint96 newlnFeeRateRoot) public onlyGovernance {
        require(newlnFeeRateRoot <= maxLnFeeRateRoot, "invalid fee rate root");
        marketConfig.lnFeeRateRoot = newlnFeeRateRoot;
    }

    function setRateOracleTimeWindow(uint32 newRateOracleTimeWindow) public onlyGovernance {
        require(newRateOracleTimeWindow >= MIN_RATE_ORACLE_TIME_WINDOW, "invalid time window");
        marketConfig.rateOracleTimeWindow = newRateOracleTimeWindow;
    }

    function setReserveFeePercent(uint8 newReserveFeePercent) public onlyGovernance {
        require(newReserveFeePercent <= 100, "invalid reserve fee percent");
        marketConfig.reserveFeePercent = newReserveFeePercent;
    }

    function setVeParams(address newVePendle, address newGaugeController) public onlyGovernance {
        require(newVePendle != address(0) && newGaugeController != address(0), "zero address");
        vePendle = newVePendle;
        gaugeController = newGaugeController;
    }
}
