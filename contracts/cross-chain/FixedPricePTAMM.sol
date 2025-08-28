// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {IPFixedPricePTAMM, IPFixedPricePTAMMSwapCallback} from "../interfaces/IPFixedPricePTAMM.sol";
import {IPChainlinkOracleEssential} from "../interfaces/IPChainlinkOracleEssential.sol";

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {PMath} from "../core/libraries/math/PMath.sol";
import {BoringOwnableUpgradeableV2} from "../core/libraries/BoringOwnableUpgradeableV2.sol";
import {TokenHelper} from "../core/libraries/TokenHelper.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract FixedPricePTAMM is
    IPFixedPricePTAMM,
    BoringOwnableUpgradeableV2,
    ReentrancyGuardUpgradeable,
    TokenHelper,
    UUPSUpgradeable
{
    // cast index-erc7201 "pendle.FixedPricePTAMM.storage"
    uint256 internal constant STORAGE_SLOT = 0xbbf04d9aae855c6bd76c8f4ba7a918994ad0d002f537323e58c83cbfe5249000;

    error OracleNotSet(address PT, address token);
    error InsufficientTokenForTrade(address token, uint256 actualAmount, uint256 requiredAmount);
    error InsufficientPtReceived(address PT, uint256 actualAmount, uint256 requiredAmount);

    using PMath for uint256;
    using PMath for int256;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        __BoringOwnableV2_init(_owner);
        __UUPSUpgradeable_init();
    }

    struct OracleData {
        address oracle;
        // @notice This can be seen as the price at maturity.
        // @notice This can help with decimals conversion.
        uint256 multiplier;
    }

    struct Storage {
        mapping(address PT => mapping(address token => OracleData)) priceOracle;
        mapping(address token => uint256) totalToken;
    }

    function $() internal pure returns (Storage storage res) {
        assembly ("memory-safe") {
            res.slot := STORAGE_SLOT
        }
    }

    function priceOracle(
        address PT,
        address token
    ) public view returns (IPChainlinkOracleEssential oracle, uint256 multiplier) {
        oracle = IPChainlinkOracleEssential($().priceOracle[PT][token].oracle);
        multiplier = $().priceOracle[PT][token].multiplier;

        if (address(oracle) == address(0)) revert OracleNotSet(PT, token);
    }

    function previewSwapPtForExactToken(
        address PT,
        address token,
        uint256 exactTokenOut
    ) public view returns (uint256 amountPtIn) {
        (IPChainlinkOracleEssential oracle, uint256 multiplier) = priceOracle(PT, token);
        (, int256 rawPrice, , , ) = oracle.latestRoundData();

        // ceil(exactTokenOut / (rawPrice * multiplier))
        return (exactTokenOut * PMath.ONE * PMath.ONE).rawDivUp(rawPrice.Uint() * multiplier);
    }

    function previewSwapExactPtForToken(
        address PT,
        uint256 exactPtIn,
        address token
    ) public view returns (uint256 amountTokenOut) {
        (IPChainlinkOracleEssential oracle, uint256 multiplier) = priceOracle(PT, token);
        (, int256 rawPrice, , , ) = oracle.latestRoundData();

        // exactPtIn * rawPrice * multiplier
        return (exactPtIn * rawPrice.Uint() * multiplier) / (PMath.ONE * PMath.ONE);
    }

    function swapPtForExactToken(
        address receiver,
        address PT,
        address token,
        uint256 exactTokenOut,
        bytes calldata data
    ) external nonReentrant returns (uint256 netPtIn) {
        netPtIn = previewSwapPtForExactToken(PT, token, exactTokenOut);
        _swap(receiver, PT, netPtIn, token, exactTokenOut, data);
    }

    function swapExactPtForToken(
        address receiver,
        address PT,
        uint256 exactPtIn,
        address token,
        bytes calldata data
    ) external nonReentrant returns (uint256 netTokenOut) {
        netTokenOut = previewSwapExactPtForToken(PT, exactPtIn, token);
        _swap(receiver, PT, exactPtIn, token, netTokenOut, data);
    }

    function _swap(
        address receiver,
        address PT,
        uint256 exactPtIn,
        address token,
        uint256 exactTokenOut,
        bytes calldata data
    ) internal {
        if ($().totalToken[token] < exactTokenOut)
            revert InsufficientTokenForTrade(token, $().totalToken[token], exactTokenOut);

        _transferOut(token, receiver, exactTokenOut);
        $().totalToken[token] -= exactTokenOut;

        if (data.length > 0) {
            IPFixedPricePTAMMSwapCallback(msg.sender).swapCallback(exactTokenOut, exactPtIn, data);
        }

        $().totalToken[PT] += exactPtIn;
        if (_selfBalance(PT) < $().totalToken[PT])
            revert InsufficientPtReceived(PT, _selfBalance(PT), $().totalToken[PT]);

        emit Swap(msg.sender, receiver, PT, exactPtIn, token, exactTokenOut);
    }

    // Admin functions

    function setPriceOracle(address PT, address token, address _priceOracle, uint256 _multiplier) external onlyOwner {
        $().priceOracle[PT][token] = OracleData(_priceOracle, _multiplier);
        emit PriceOracleUpdated(PT, token, _priceOracle);
    }

    function addFund(address token, uint256 amount) external payable onlyOwner {
        _transferIn(token, owner, amount);
        $().totalToken[token] += amount;
        emit Seeded(token, amount);
    }

    function removeFund(address token, uint256 amount) external onlyOwner {
        _transferOut(token, owner, amount);
        $().totalToken[token] -= amount;
        emit Unseeded(token, amount);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
