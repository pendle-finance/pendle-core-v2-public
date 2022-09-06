// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPYieldContractFactory.sol";
import "../../interfaces/IPMarketFactory.sol";

import "../../libraries/helpers/BaseSplitCodeFactory.sol";
import "../../periphery/BoringOwnableUpgradeable.sol";

import "./PendleMarket.sol";
import "../LiquidityMining/PendleGauge.sol";

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
        require(_yieldContractFactory != address(0), "zero address");
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
        require(newVePendle != address(0) && newGaugeController != address(0), "zero address");

        __BoringOwnable_init();
        setTreasury(_treasury);
        setlnFeeRateRoot(_lnFeeRateRoot);
        setReserveFeePercent(_reserveFeePercent);

        vePendle = newVePendle;
        gaugeController = newGaugeController;
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
        require(!IPPrincipalToken(PT).isExpired(), "PT is expired");
        require(IPYieldContractFactory(yieldContractFactory).isPT(PT), "Invalid PT");
        require(markets[PT][scalarRoot][initialAnchor] == address(0), "market already created");

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
        require(allMarkets.add(market), "IE market can't be added");

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
        require(newTreasury != address(0), "zero address");
        marketConfig.treasury = newTreasury;
        _emitNewMarketConfigEvent();
    }

    function setlnFeeRateRoot(uint88 newlnFeeRateRoot) public onlyOwner {
        require(newlnFeeRateRoot <= maxLnFeeRateRoot, "invalid fee rate root");
        marketConfig.lnFeeRateRoot = newlnFeeRateRoot;
        _emitNewMarketConfigEvent();
    }

    function setReserveFeePercent(uint8 newReserveFeePercent) public onlyOwner {
        require(newReserveFeePercent <= 100, "invalid reserve fee percent");
        marketConfig.reserveFeePercent = newReserveFeePercent;
        _emitNewMarketConfigEvent();
    }

    function _emitNewMarketConfigEvent() internal {
        MarketConfig memory local = marketConfig;
        emit NewMarketConfig(local.treasury, local.lnFeeRateRoot, local.reserveFeePercent);
    }
}
