// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IPPausingInterface.sol";
import "../interfaces/IPVirtualGovernance.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract PendleVirtualGovernance is AccessControlUpgradeable, UUPSUpgradeable, IPVirtualGovernance {
    bytes32 public constant GUARDIAN = keccak256("GUARDIAN");

    modifier onlyPauseGuardian() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(GUARDIAN, msg.sender), "not authorized");
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "not authorized");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /*///////////////////////////////////////////////////////////////
                                PAUSING
    //////////////////////////////////////////////////////////////*/

    function pause(address[] calldata addrs) external onlyPauseGuardian {
        for (uint256 i = 0; i < addrs.length; ++i) {
            IPPausingInterface(addrs[i]).pause();
        }
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN CALL
    //////////////////////////////////////////////////////////////*/

    function aggregate(IPVirtualGovernance.Call[] calldata calls) external payable onlyAdmin {
        uint256 length = calls.length;
        Call calldata call;
        for (uint256 i = 0; i < length; ) {
            call = calls[i];

            (bool success, bytes memory resp) = call.target.call{value: calls[i].value}(call.callData);
            if (!success) {
                assembly {
                    revert(add(32, resp), mload(resp))
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    receive() external payable {}

    /*///////////////////////////////////////////////////////////////
                            UPGRADABLE RELATED
    //////////////////////////////////////////////////////////////*/

    function initialize(address governance) external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, governance);
    }

    function _authorizeUpgrade(address) internal view override onlyAdmin {}

    uint256[49] private __gap;
}
