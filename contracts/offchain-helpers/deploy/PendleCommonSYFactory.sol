// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../core/libraries/BoringOwnableUpgradeableV2.sol";
import "../../core/libraries/BaseSplitCodeFactory.sol";
import "../../interfaces/IOwnable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract PendleCommonSYFactory is BoringOwnableUpgradeableV2 {
    error InvalidCreationCode(bytes32 id, CreationCode code);

    error InvalidSYId(bytes32 id);

    struct CreationCode {
        address creationCodeContractA;
        uint256 creationCodeSizeA;
        address creationCodeContractB;
        uint256 creationCodeSizeB;
    }

    event SetSYCreationCode(bytes32 id, CreationCode code);

    event DeployedSY(bytes32 id, bytes constructorParams, address SY);

    address public immutable proxyAdmin;

    mapping(bytes32 => CreationCode) public creationCodes;

    uint256 public nonce;

    mapping(bytes32 => address) public implementations;

    constructor(address _proxyAdmin) {
        proxyAdmin = _proxyAdmin;
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        __BoringOwnableV2_init(_owner);
    }

    function setSYCreationCode(bytes32 id, CreationCode memory code) external onlyOwner {
        if (
            code.creationCodeContractA == address(0) ||
            code.creationCodeContractB == address(0) ||
            code.creationCodeSizeA == 0 ||
            code.creationCodeSizeB == 0
        ) {
            revert InvalidCreationCode(id, code);
        }
        creationCodes[id] = code;
        emit SetSYCreationCode(id, code);
    }

    function deploySY(bytes32 id, bytes memory constructorParams, address syOwner) external returns (address SY) {
        CreationCode memory code = creationCodes[id];

        if (code.creationCodeContractA == address(0)) {
            revert InvalidSYId(id);
        }

        SY = BaseSplitCodeFactory._create2(
            0,
            keccak256(abi.encode(block.chainid, nonce++)),
            constructorParams,
            code.creationCodeContractA,
            code.creationCodeSizeA,
            code.creationCodeContractB,
            code.creationCodeSizeB
        );

        emit DeployedSY(id, constructorParams, SY);
        IOwnable(SY).transferOwnership(syOwner, true, false);
    }

    function deployUpgradableSY(
        bytes32 id,
        bytes memory constructorParams,
        bytes memory initData,
        address syOwner
    ) external returns (address) {
        CreationCode memory code = creationCodes[id];

        if (code.creationCodeContractA == address(0)) {
            revert InvalidSYId(id);
        }

        address implementation = BaseSplitCodeFactory._create2(
            0,
            keccak256(abi.encode(block.chainid, nonce++)),
            constructorParams,
            code.creationCodeContractA,
            code.creationCodeSizeA,
            code.creationCodeContractB,
            code.creationCodeSizeB
        );
        address proxy = address(new TransparentUpgradeableProxy(implementation, proxyAdmin, initData));

        emit DeployedSY(id, constructorParams, proxy);

        IOwnable(proxy).transferOwnership(syOwner, true, false);
        return proxy;
    }
}
