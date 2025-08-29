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

    mapping(bytes4 => bytes32) public __deprecated_allowedSelectors;

    // Only the admin (governance) of PendleGovernanceProxy can modify one address to be
    // a selector admin of some selectors.
    //
    // A [selector admin] of a selector can grant/revoke scoped access of that selector
    // to/from ANY caller and ANY target.
    //
    // For example: 0xdeployer is a selector admin of `updateSupplyCap(uint256)`, he can
    // grant/revoke the scoped access of, say 0xalice to call `updateSupplyCap(uint256)`
    // on ANY target contract (in this case, SYs).
    //
    // Changes on execution:
    // - aggregate(Call[]): is now callable by admin only
    // - aggregateWithScopedAccess(Call[]): new function to let anyone with scoped access
    // to execute calls

    mapping(address => mapping(bytes4 => bool)) public isSelectorAdminOf;
    mapping(address => mapping(bytes4 => mapping(address => bool))) public hasScopedAccess;

    modifier onlyGuardian() {
        require(hasRole(GUARDIAN, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "PGP: n/a");
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "PGP: n/a");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function aggregate(Call[] calldata calls) external payable onlyAdmin returns (bytes[] memory) {
        return _aggregate(calls);
    }

    /*///////////////////////////////////////////////////////////////
                            SCOPED ACCESS
    //////////////////////////////////////////////////////////////*/

    function modifySelectorAdmin(
        address addr,
        bytes4[] memory selectors,
        bool[] memory isAdmins
    ) external onlyAdmin {
        require(selectors.length == isAdmins.length, "PGP: Array length mismatch");

        for (uint256 i = 0; i < selectors.length; i++) {
            isSelectorAdminOf[addr][selectors[i]] = isAdmins[i];
            emit ModifySelectorAdmin(addr, selectors[i], isAdmins[i]);
        }
    }

    function grantScopedAccess(
        address caller,
        address[] memory targets,
        bytes4[] memory selectors,
        bool[] memory accesses
    ) external {
        require(targets.length == selectors.length && targets.length == accesses.length, "PGP: Array length mismatch");

        bool isAdmin = hasRole(DEFAULT_ADMIN_ROLE, msg.sender);

        for (uint256 i = 0; i < targets.length; i++) {
            require(isAdmin || isSelectorAdminOf[msg.sender][selectors[i]], "PGP: n/a");
            hasScopedAccess[caller][selectors[i]][targets[i]] = accesses[i];
            emit GrantScopedAccess(caller, targets[i], selectors[i], accesses[i]);
        }
    }

    function aggregateWithScopedAccess(Call[] calldata calls) external payable returns (bytes[] memory) {
        for (uint256 i = 0; i < calls.length; i++) {
            bytes4 selector = bytes4(calls[i].callData[:4]);
            require(hasScopedAccess[msg.sender][selector][calls[i].target], "PGP: n/a");
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
