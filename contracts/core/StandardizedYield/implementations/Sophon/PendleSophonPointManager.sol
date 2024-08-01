// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../../erc20/PendleERC20.sol";
import "../../../libraries/BoringOwnableUpgradeable.sol";
import "../../../../interfaces/Sophon/ISophonFarming.sol";
import "../../../../interfaces/Sophon/IPSophonPointManager.sol";

contract PendleSophonPointManager is PendleERC20, BoringOwnableUpgradeable, IPSophonPointManager {
    // solhint-disable immutable-vars-naming
    address public immutable sophonFarming;
    uint256 public immutable pid;
    address public immutable sy;

    mapping(address => bool) public isAddressWhitelisted;

    constructor(
        address _sophonFarming,
        uint256 _pid,
        address _sy
    ) PendleERC20("Sophon Point Receipt Token", "SPOINT", 18) initializer {
        sophonFarming = _sophonFarming;
        pid = _pid;
        sy = _sy;
        __BoringOwnable_init();
    }

    function claimPointReceiptToken() external {
        uint256 floatingPoints = _getOwningPoints() - totalSupply();
        _mint(sy, floatingPoints);
    }

    function addWhitelistedAddress(address addr) external onlyOwner {
        isAddressWhitelisted[addr] = true;
    }

    function _getOwningPoints() internal view returns (uint256) {
        return ISophonFarming(sophonFarming).pendingPoints(pid, address(this));
    }

    function _afterTokenTransfer(address, address to, uint256 amount) internal virtual override {
        if (to != address(0) && _shouldBurnReceiptToken(to)) {
            _burn(to, amount);
            ISophonFarming(sophonFarming).transferPoints(pid, address(this), to, amount);
        }
    }

    function _shouldBurnReceiptToken(address addr) internal view returns (bool) {
        return addr != sy && !isAddressWhitelisted[addr];
    }
}
