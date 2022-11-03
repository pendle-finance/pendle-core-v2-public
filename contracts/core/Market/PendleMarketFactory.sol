// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPYieldContractFactory.sol";
import "../../interfaces/IPMarketFactory.sol";

import "../libraries/BaseSplitCodeFactory.sol";
import "../libraries/Errors.sol";
import "../libraries/BoringOwnableUpgradeable.sol";

import "./PendleMarket.sol";
import "./PendleGauge.sol";

contract PendleMarketFactory is BoringOwnableUpgradeable, IPMarketFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct MarketConfig {
        address treasury;
        uint88 lnFeeRateRoot;
        uint8 reserveFeePercent;
        // 1 SLOT = 256 bits
    }

    address public immutable marketCreationCodeContractA;
    uint256 public immutable marketCreationCodeSizeA;
    address public immutable marketCreationCodeContractB;
    uint256 public immutable marketCreationCodeSizeB;

    address public immutable yieldContractFactory;
    uint256 public immutable maxLnFeeRateRoot;
    uint8 public constant maxReserveFeePercent = 100;
    int256 public constant minInitialAnchor = Math.IONE;

    // PT -> scalarRoot -> initialAnchor
    mapping(address => mapping(int256 => mapping(int256 => address))) internal markets;
    EnumerableSet.AddressSet internal allMarkets;
    address public vePendle;
    address public gaugeController;

    MarketConfig public marketConfig;

    constructor(
        address _yieldContractFactory,
        address _marketCreationCodeContractA,
        uint256 _marketCreationCodeSizeA,
        address _marketCreationCodeContractB,
        uint256 _marketCreationCodeSizeB
    ) {
        yieldContractFactory = _yieldContractFactory;
        maxLnFeeRateRoot = uint256(LogExpMath.ln(int256((105 * Math.IONE) / 100))); // ln(1.05)

        marketCreationCodeContractA = _marketCreationCodeContractA;
        marketCreationCodeSizeA = _marketCreationCodeSizeA;
        marketCreationCodeContractB = _marketCreationCodeContractB;
        marketCreationCodeSizeB = _marketCreationCodeSizeB;
    }

    function initialize(
        address _treasury,
        uint88 _lnFeeRateRoot,
        uint8 _reserveFeePercent,
        address newVePendle,
        address newGaugeController
    ) external initializer {
        __BoringOwnable_init();
        setTreasury(_treasury);
        setlnFeeRateRoot(_lnFeeRateRoot);
        setReserveFeePercent(_reserveFeePercent);

        vePendle = newVePendle;
        gaugeController = newGaugeController;
    }

    /**
     * @notice Create a market between PT and its corresponding SY with scalar & anchor config. 
     * Anyone is allowed to create a market on their own.
     */
    function createNewMarket(
        address PT,
        int256 scalarRoot,
        int256 initialAnchor
    ) external returns (address market) {
        if (!IPYieldContractFactory(yieldContractFactory).isPT(PT))
            revert Errors.MarketFactoryInvalidPt();
        if (IPPrincipalToken(PT).isExpired()) revert Errors.MarketFactoryExpiredPt();

        if (markets[PT][scalarRoot][initialAnchor] != address(0))
            revert Errors.MarketFactoryMarketExists();

        if (initialAnchor < minInitialAnchor)
            revert Errors.MarketFactoryInitialAnchorTooLow(initialAnchor, minInitialAnchor);

        market = BaseSplitCodeFactory._create2(
            0,
            bytes32(block.chainid),
            abi.encode(PT, scalarRoot, initialAnchor, vePendle, gaugeController),
            marketCreationCodeContractA,
            marketCreationCodeSizeA,
            marketCreationCodeContractB,
            marketCreationCodeSizeB
        );

        markets[PT][scalarRoot][initialAnchor] = market;

        if (!allMarkets.add(market)) assert(false);

        emit CreateNewMarket(market, PT, scalarRoot, initialAnchor);
    }

    /// @dev for gas-efficient verification of market
    function isValidMarket(address market) external view returns (bool) {
        return allMarkets.contains(market);
    }

    function treasury() external view returns (address) {
        return marketConfig.treasury;
    }

    function setTreasury(address newTreasury) public onlyOwner {
        if (newTreasury == address(0)) revert Errors.MarketFactoryZeroTreasury();

        marketConfig.treasury = newTreasury;
        _emitNewMarketConfigEvent();
    }

    function setlnFeeRateRoot(uint88 newLnFeeRateRoot) public onlyOwner {
        if (newLnFeeRateRoot > maxLnFeeRateRoot)
            revert Errors.MarketFactoryLnFeeRateRootTooHigh(newLnFeeRateRoot, maxLnFeeRateRoot);

        marketConfig.lnFeeRateRoot = newLnFeeRateRoot;
        _emitNewMarketConfigEvent();
    }

    function setReserveFeePercent(uint8 newReserveFeePercent) public onlyOwner {
        if (newReserveFeePercent > maxReserveFeePercent)
            revert Errors.MarketFactoryReserveFeePercentTooHigh(
                newReserveFeePercent,
                maxReserveFeePercent
            );

        marketConfig.reserveFeePercent = newReserveFeePercent;
        _emitNewMarketConfigEvent();
    }

    function _emitNewMarketConfigEvent() internal {
        MarketConfig memory local = marketConfig;
        emit NewMarketConfig(local.treasury, local.lnFeeRateRoot, local.reserveFeePercent);
    }
}
