// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {BoringOwnableUpgradeableV2} from "../core/libraries/BoringOwnableUpgradeableV2.sol";
import {IPTokenPriceRegistry} from "../interfaces/IPTokenPriceRegistry.sol";

contract PendleTokenPriceRegistry is IPTokenPriceRegistry, BoringOwnableUpgradeableV2 {
    address public maintainer;

    mapping(address token => uint256) public tokenPrice;

    modifier onlyMaintainer() {
        require(msg.sender == owner || msg.sender == maintainer, "TokenPriceRegistry: caller is not a maintainer");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        __BoringOwnableV2_init(_owner);
    }

    function setMaintainer(address newMaintainer) external onlyOwner {
        maintainer = newMaintainer;
        emit MaintainerSet(newMaintainer);
    }

    function setTokenPrices(address[] calldata tokens, uint256[] calldata prices) external onlyMaintainer {
        require(tokens.length == prices.length, "TokenPriceRegistry: length mismatch");
        for (uint256 i = 0; i < tokens.length; ++i) {
            tokenPrice[tokens[i]] = prices[i];
            emit TokenPriceSet(tokens[i], prices[i]);
        }
    }
}
