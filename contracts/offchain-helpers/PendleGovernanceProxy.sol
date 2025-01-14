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

    bytes32 public constant ALICE = keccak256("ALICE");
    bytes32 public constant BOB = keccak256("BOB");
    bytes32 public constant CHARLIE = keccak256("CHARLIE");

    mapping(bytes4 => bytes32) public allowedSelectors;

    modifier onlyGuardian() {
        require(hasRole(GUARDIAN, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "n/a");
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "n/a");
        _;
    }

    modifier onlyHaveSomeRole() {
        require(
            hasRole(ALICE, msg.sender) ||
                hasRole(BOB, msg.sender) ||
                hasRole(CHARLIE, msg.sender) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "n/a"
        );
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function aggregate(Call[] calldata calls) external payable onlyHaveSomeRole returns (bytes[] memory) {
        bool isAdmin = hasRole(DEFAULT_ADMIN_ROLE, msg.sender);

        if (!isAdmin) {
            for (uint256 i = 0; i < calls.length; i++) {
                bytes4 selector = bytes4(calls[i].callData[:4]);
                require(hasRole(allowedSelectors[selector], msg.sender), "n/a");
            }
        }

        return _aggregate(calls);
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

    function setAllowedSelectors(bytes4[] calldata selectors, bytes32 role) external onlyAdmin {
        for (uint256 i = 0; i < selectors.length; i++) {
            allowedSelectors[selectors[i]] = role;
        }
        emit SetAllowedSelectors(selectors, role);
    }

    function _aggregate(Call[] calldata calls) internal returns (bytes[] memory rtnData) {
        uint256 length = calls.length;
        rtnData = new bytes[](length);

        Call calldata call;
        for (uint256 i = 0; i < length; i++) {
            call = calls[i];

            (bool success, bytes memory resp) = call.target.call{value: call.value}(call.callData);
            if (!success) {
                assembly {
                    revert(add(32, resp), mload(resp))
                }
            }

            rtnData[i] = resp;
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
