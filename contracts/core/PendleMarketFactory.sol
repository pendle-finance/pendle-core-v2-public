// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPYieldContractFactory.sol";
import "../interfaces/IPMarketFactory.sol";
import "../periphery/PermissionsV2Upg.sol";
import "./PendleMarket.sol";
import "./LiquidityMining/PendleGauge.sol";
import "../libraries/helpers/MiniDeployer.sol";

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

    mapping(address => EnumerableSet.AddressSet) internal markets;

    address public immutable yieldContractFactory;
    address public vePendle;
    address public gaugeController;
    address public immutable marketCreationCodePointer;

    uint256 public immutable maxLnFeeRateRoot;
    uint256 public constant minRateOracleTimeWindow = 300 seconds;
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
        _verifyPT(PT);
        require(vePendle != address(0), "vePendle unset");
        require(gaugeController != address(0), "gaugeController unset");

        market = _deployWithArgs(
            marketCreationCodePointer,
            abi.encode(PT, scalarRoot, initialAnchor, vePendle, gaugeController)
        );
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
        require(newlnFeeRateRoot <= maxLnFeeRateRoot, "invalid fee rate root");
        marketConfig.lnFeeRateRoot = newlnFeeRateRoot;
    }

    function setRateOracleTimeWindow(uint32 newRateOracleTimeWindow) public onlyGovernance {
        require(newRateOracleTimeWindow >= minRateOracleTimeWindow, "invalid time window");
        marketConfig.rateOracleTimeWindow = newRateOracleTimeWindow;
    }

    function setReserveFeePercent(uint8 newReserveFeePercent) public onlyGovernance {
        require(newReserveFeePercent <= 100, "invalid reserve fee percent");
        marketConfig.reserveFeePercent = newReserveFeePercent;
    }

    function setVeParams(address newVePendle, address newGaugeController) public onlyGovernance {
        vePendle = newVePendle;
        gaugeController = newGaugeController;
    }

    function _verifyPT(address PT) internal view {
        address SCY = IPPrincipalToken(PT).SCY();
        uint256 expiry = IPPrincipalToken(PT).expiry();

        require(
            IPYieldContractFactory(yieldContractFactory).getPT(SCY, expiry) == PT,
            "INVALID_PT"
        );
    }
}
