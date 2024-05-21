// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IPPausingInterface.sol";
import "../interfaces/IPGovernanceProxy.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

// solhint-disable custom-errors
// solhint-disable no-inline-assembly
// solhint-disable no-empty-blocks

contract PendleGovernanceProxy is AccessControlUpgradeable, UUPSUpgradeable, IPGovernanceProxy {
    bytes32 public constant GUARDIAN = keccak256("GUARDIAN");

    modifier onlyGuardian() {
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

    function pause(address[] calldata addrs) external onlyGuardian {
        uint256 length = addrs.length;
        for (uint256 i = 0; i < length; ) {
            IPPausingInterface(addrs[i]).pause();
            unchecked {
                ++i;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN CALL
    //////////////////////////////////////////////////////////////*/

    function aggregate(
        IPGovernanceProxy.Call[] calldata calls
    ) external payable onlyAdmin returns (bytes[] memory rtnData) {
        uint256 length = calls.length;
        rtnData = new bytes[](length);

        Call calldata call;
        for (uint256 i = 0; i < length; ) {
            call = calls[i];

            (bool success, bytes memory resp) = call.target.call{value: call.value}(call.callData);
            if (!success) {
                assembly {
                    revert(add(32, resp), mload(resp))
                }
            }

            rtnData[i] = resp;

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
}
