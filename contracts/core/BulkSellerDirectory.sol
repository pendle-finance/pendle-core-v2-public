// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./libraries/TokenHelper.sol";
import "./libraries/math/Math.sol";
import "./libraries/Errors.sol";
import "./libraries/BoringOwnableUpgradeable.sol";
import "./BulkSellerMathCore.sol";
import "../interfaces/IStandardizedYield.sol";
import "../interfaces/IPBulkSeller.sol";
import "../interfaces/IPBulkSellerDirectory.sol";

contract BulkSellerDirectory is IPBulkSellerDirectory, BoringOwnableUpgradeable {
    mapping(address => mapping(address => address)) internal syToBulkSeller;

    constructor() initializer {
        __BoringOwnable_init();
    }

    function setBulkSeller(address bulkSeller, bool force) external onlyOwner {
        address token = IPBulkSeller(bulkSeller).token();
        address SY = IPBulkSeller(bulkSeller).SY();

        if (force) {
            syToBulkSeller[token][SY] = bulkSeller;
        } else {
            require(syToBulkSeller[token][SY] == address(0), "bulk seller already exists");
            syToBulkSeller[token][SY] = bulkSeller;
        }
    }

    function get(address token, address SY) external view override returns (address) {
        if (syToBulkSeller[token][SY] == address(0))
            revert Errors.RouterBulkSellerNotFound(token, SY);
        return syToBulkSeller[token][SY];
    }
}
