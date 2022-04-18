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
        uint96 feeRateRoot; // 96 bit
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
        uint96 _feeRateRoot,
        uint32 _rateOracleTimeWindow,
        uint8 _reserveFeePercent
    ) PermissionsV2Upg(_governanceManager) {
        yieldContractFactory = _yieldContractFactory;

        setTreasury(_treasury);
        setFeeRateRoot(_feeRateRoot);
        setRateOracleTimeWindow(_rateOracleTimeWindow);
        setReserveFeePercent(_reserveFeePercent);
    }

    function createNewMarket(
        address OT,
        int256 scalarRoot,
        int256 initialAnchor
    ) external returns (address market) {
        address SCY = IPOwnershipToken(OT).SCY();
        uint256 expiry = IPOwnershipToken(OT).expiry();

        require(
            IPYieldContractFactory(yieldContractFactory).getOT(SCY, expiry) == OT,
            "INVALID_OT"
        );

        market = address(new PendleMarket(OT, scalarRoot, initialAnchor));
        markets[OT].add(market);
    }

    function isValidMarket(address market) external view returns (bool) {
        address OT = IPMarket(market).OT();
        return markets[OT].contains(market);
    }

    function treasury() external view returns (address) {
        return marketConfig.treasury;
    }

    function setTreasury(address newTreasury) public onlyGovernance {
        require(newTreasury != address(0), "zero address");
        marketConfig.treasury = newTreasury;
    }

    function setFeeRateRoot(uint96 newFeeRateRoot) public onlyGovernance {
        // TODO: hard cap on the fee
        marketConfig.feeRateRoot = newFeeRateRoot;
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
