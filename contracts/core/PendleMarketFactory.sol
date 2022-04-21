// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPYieldContractFactory.sol";
import "../interfaces/IPMarketFactory.sol";
import "../periphery/PermissionsV2Upg.sol";
import "./PendleMarket.sol";

contract PendleMarketFactory is PermissionsV2Upg, IPMarketFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct MarketConfig {
        address treasury; // 160 bit
        uint96 lnFeeRateRoot; // 96 bit
        // 1 SLOT
        uint32 rateOracleTimeWindow;
        uint8 reserveFeePercent;
    }

    mapping(address => EnumerableSet.AddressSet) internal markets;

    address public immutable yieldContractFactory;

    MarketConfig public marketConfig;

    constructor(
        address _governanceManager,
        address _yieldContractFactory,
        address _treasury,
        uint96 _lnFeeRateRoot,
        uint32 _rateOracleTimeWindow,
        uint8 _reserveFeePercent
    ) PermissionsV2Upg(_governanceManager) {
        require(_yieldContractFactory != address(0), "zero address");
        yieldContractFactory = _yieldContractFactory;

        setTreasury(_treasury);
        setlnFeeRateRoot(_lnFeeRateRoot);
        setRateOracleTimeWindow(_rateOracleTimeWindow);
        setReserveFeePercent(_reserveFeePercent);
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
        address SCY = IPPrincipalToken(PT).SCY();
        uint256 expiry = IPPrincipalToken(PT).expiry();

        require(
            IPYieldContractFactory(yieldContractFactory).getPT(SCY, expiry) == PT,
            "INVALID_PT"
        );

        market = address(new PendleMarket(PT, scalarRoot, initialAnchor));
        require(markets[PT].add(market), "market add failed");

        emit CreateNewMarket(PT, scalarRoot, initialAnchor);
    }

    function isValidMarket(address market) external view returns (bool) {
        address PT = IPMarket(market).PT();
        return markets[PT].contains(market);
    }

    function treasury() external view returns (address) {
        return marketConfig.treasury;
    }

    function setTreasury(address newTreasury) public onlyGovernance {
        require(newTreasury != address(0), "zero address");
        marketConfig.treasury = newTreasury;
    }

    function setlnFeeRateRoot(uint96 newlnFeeRateRoot) public onlyGovernance {
        // TODO: hard cap on the fee
        marketConfig.lnFeeRateRoot = newlnFeeRateRoot;
    }

    function setRateOracleTimeWindow(uint32 newRateOracleTimeWindow) public onlyGovernance {
        // TODO: hard min for the time window
        marketConfig.rateOracleTimeWindow = newRateOracleTimeWindow;
    }

    function setReserveFeePercent(uint8 newReserveFeePercent) public onlyGovernance {
        require(newReserveFeePercent <= 100, "invalid fee rate");
        marketConfig.reserveFeePercent = newReserveFeePercent;
    }
}
