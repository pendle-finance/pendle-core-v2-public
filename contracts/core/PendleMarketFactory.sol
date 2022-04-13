// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPYieldContractFactory.sol";
import "../interfaces/IPMarketFactory.sol";
import "../periphery/PermissionsV2.sol";
import "./PendleMarket.sol";

contract PendleMarketFactory is PermissionsV2, IPMarketFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => EnumerableSet.AddressSet) internal otMarkets;
    address public immutable yieldContractFactory;
    address public treasury;

    constructor(address _governanceManager, address _yieldContractFactory)
        PermissionsV2(_governanceManager)
    {
        yieldContractFactory = _yieldContractFactory;
    }

    function createNewMarket(
        address OT,
        uint256 feeRateRoot,
        int256 scalarRoot,
        int256 initialAnchor,
        uint8 reserveFeePercent,
        uint256 rateOracleTimeWindow
    ) external returns (address market) {
        address SCY = IPOwnershipToken(OT).SCY();
        uint256 expiry = IPOwnershipToken(OT).expiry();

        require(
            IPYieldContractFactory(yieldContractFactory).getOT(SCY, expiry) == OT,
            "INVALID_OT"
        );

        market = address(
            new PendleMarket(
                OT,
                rateOracleTimeWindow,
                feeRateRoot,
                scalarRoot,
                initialAnchor,
                reserveFeePercent
            )
        );
        otMarkets[address(OT)].add(market);
    }

    function setTreasury(address newTreasury) external onlyGovernance {
        treasury = newTreasury;
    }

    function isValidMarket(address market) external view returns (bool) {
        address OT = IPMarket(market).OT();
        return otMarkets[OT].contains(market);
    }
}
