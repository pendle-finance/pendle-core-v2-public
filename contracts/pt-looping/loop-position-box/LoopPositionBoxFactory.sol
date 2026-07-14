// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {BoringOwnableUpgradeableV2} from "../../core/libraries/BoringOwnableUpgradeableV2.sol";
import {IMoneyMarket, createMarketCtx} from "../../interfaces/IMoneyMarket.sol";
import {BoxData, IPLoopPositionBox} from "../../interfaces/IPLoopPositionBox.sol";
import {IPLoopPositionBoxFactory} from "../../interfaces/IPLoopPositionBoxFactory.sol";

contract LoopPositionBoxFactory is IPLoopPositionBoxFactory, BoringOwnableUpgradeableV2 {
    /// @dev creation code of OpenZeppelin's BeaconProxy
    address public immutable BEACON_PROXY_CODE_CONTRACT;
    address public immutable POSITION_BOX_BEACON;
    bytes32 public immutable POSITION_BOX_CODE_HASH;

    /// @dev Domain separator string baked into every boxId hash. Must not change — would
    /// invalidate every previously-registered box.
    string private constant BOX_ID_DOMAIN = "LoopPositionBox";

    mapping(bytes32 boxId => BoxData) internal _boxData;

    constructor(address _beaconProxyCodeContract, address _positionBoxBeacon) {
        _disableInitializers();
        BEACON_PROXY_CODE_CONTRACT = _beaconProxyCodeContract;
        POSITION_BOX_BEACON = _positionBoxBeacon;
        POSITION_BOX_CODE_HASH = keccak256(_beaconProxyInitCodeNoData(_positionBoxBeacon));
    }

    function initialize(address _owner) public initializer {
        __BoringOwnableV2_init(_owner);
    }

    function boxData(bytes32 boxId) public view returns (BoxData memory bd) {
        bd = _boxData[boxId];
        require(bd.hubPt != address(0), "LoopPositionBoxFactory: box not registered");
    }

    function getBoxId(BoxData memory bd) public pure returns (bytes32) {
        return keccak256(abi.encode(BOX_ID_DOMAIN, bd));
    }

    function computePositionBox(address owner, bytes32 boxId)
        public
        view
        returns (address box, bytes32 salt, bool deployed)
    {
        salt = keccak256(abi.encode(owner, boxId));
        box = Create2.computeAddress(salt, POSITION_BOX_CODE_HASH);
        deployed = box.code.length > 0;
    }

    function computeMoneyMarket(address owner, bytes32 boxId)
        public
        view
        returns (address computedAddr, bytes32 salt, bool deployed)
    {
        (computedAddr,, salt, deployed,) = _computeMoneyMarket(owner, boxId);
    }

    function _computeMoneyMarket(address owner, bytes32 boxId)
        internal
        view
        returns (address computedAddr, bytes memory mmInitCode, bytes32 salt, bool deployed, BoxData memory bd)
    {
        bd = boxData(boxId);
        if (bd.spokeChainId != block.chainid) {
            return (address(0), "", bytes32(0), false, bd);
        }

        salt = keccak256(abi.encode(owner, boxId));
        mmInitCode = _beaconProxyInitCodeNoData(bd.spokeMMBeacon);
        computedAddr = Create2.computeAddress(salt, keccak256(mmInitCode));
        deployed = computedAddr.code.length > 0;
    }

    function deployPositionBoxAndMoneyMarket(address owner, bytes32 boxId)
        external
        returns (IPLoopPositionBox box, IMoneyMarket mm, BoxData memory bd)
    {
        (address boxAddr, bytes32 boxSalt, bool boxDeployed) = computePositionBox(owner, boxId);
        box = IPLoopPositionBox(payable(boxAddr));

        (address mmAddr, bytes memory mmInitCode, bytes32 mmSalt, bool mmDeployed, BoxData memory _bd) =
            _computeMoneyMarket(owner, boxId);

        mm = IMoneyMarket(mmAddr);
        bd = _bd;
        if (mmAddr != address(0) && !mmDeployed) {
            assert(Create2.deploy(0, mmSalt, mmInitCode) == mmAddr);
            mm.initialize(createMarketCtx(box, bd));
        }

        if (!boxDeployed) {
            bytes memory bytecode = _beaconProxyInitCodeNoData(POSITION_BOX_BEACON);
            assert(Create2.deploy(0, boxSalt, bytecode) == boxAddr);

            (address ptToApprove, address debtTokenToApprove) =
                address(mm) == address(0) ? (address(0), address(0)) : (bd.spokePt, bd.spokeDebtToken);
            box.initialize(owner, boxId, address(mm), ptToApprove, debtTokenToApprove);
        }
    }

    // ========== Admin functions ==========

    function registerBoxData(BoxData calldata bd) external onlyOwner returns (bytes32 boxId) {
        require(
            bd.hubChainId == block.chainid || bd.spokeChainId == block.chainid,
            "LoopPositionBoxFactory: invalid chain id"
        );

        boxId = getBoxId(bd);
        _boxData[boxId] = bd;

        emit BoxDataRegistered(boxId, bd);
    }

    // ========== Internal helpers ==========

    function _beaconProxyInitCodeNoData(address beacon) internal view returns (bytes memory) {
        return abi.encodePacked(BEACON_PROXY_CODE_CONTRACT.code, abi.encode(beacon, ""));
    }
}
