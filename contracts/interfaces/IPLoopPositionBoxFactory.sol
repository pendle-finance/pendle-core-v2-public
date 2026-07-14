// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMoneyMarket} from "./IMoneyMarket.sol";
import {BoxData, IPLoopPositionBox} from "./IPLoopPositionBox.sol";

interface IPLoopPositionBoxFactory {
    event BoxDataRegistered(bytes32 indexed boxId, BoxData boxData);

    function boxData(bytes32 boxId) external view returns (BoxData memory);

    function computePositionBox(address owner, bytes32 boxId)
        external
        view
        returns (address box, bytes32 salt, bool deployed);

    /// @notice return computedAddr == address(0) when not on spoke chain
    function computeMoneyMarket(address owner, bytes32 boxId)
        external
        view
        returns (address computedAddr, bytes32 salt, bool deployed);

    /// @notice return mm == address(0) when not on spoke chain
    function deployPositionBoxAndMoneyMarket(address owner, bytes32 boxId)
        external
        returns (IPLoopPositionBox box, IMoneyMarket mm, BoxData memory boxData);

    function BEACON_PROXY_CODE_CONTRACT() external view returns (address);

    function POSITION_BOX_BEACON() external view returns (address);

    function POSITION_BOX_CODE_HASH() external view returns (bytes32);

    // ========== Admin functions ==========

    function registerBoxData(BoxData calldata boxData) external returns (bytes32 boxId);
}
