// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {IPChainlinkOracleEssential} from "../interfaces/IPChainlinkOracleEssential.sol";
import {IPFixedPricePTAMMSwapCallback, IPFixedPricePTAMMV2} from "../interfaces/IPFixedPricePTAMMV2.sol";

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    IERC20MetadataUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {BoringOwnableUpgradeableV2} from "../core/libraries/BoringOwnableUpgradeableV2.sol";
import {TokenHelper} from "../core/libraries/TokenHelper.sol";
import {PMath} from "../core/libraries/math/PMath.sol";

contract FixedPricePTAMMV2 is
    IPFixedPricePTAMMV2,
    BoringOwnableUpgradeableV2,
    ERC20Upgradeable,
    ReentrancyGuardUpgradeable,
    TokenHelper
{
    // cast index-erc7201 "pendle.FixedPricePTAMM.storage"
    uint256 internal constant STORAGE_SLOT = 0xbbf04d9aae855c6bd76c8f4ba7a918994ad0d002f537323e58c83cbfe5249000;

    using PMath for uint256;
    using PMath for int256;

    address public immutable outputToken;

    constructor(address _outputToken) {
        _disableInitializers();
        outputToken = _outputToken;
    }

    function initialize(address _owner) external initializer {
        __BoringOwnableV2_init(_owner);
        __ERC20_init(
            string.concat(IERC20Metadata(outputToken).name(), " receipt"),
            string.concat(IERC20Metadata(outputToken).symbol(), "-receipt")
        );
        __ReentrancyGuard_init();
    }

    function decimals() public view override(ERC20Upgradeable, IERC20MetadataUpgradeable) returns (uint8) {
        return IERC20Metadata(outputToken).decimals();
    }

    struct OracleData {
        bool isPaused;
        address oracle;
        // @notice This can be seen as the price at maturity.
        // @notice This can help with decimals conversion.
        uint256 multiplier;
    }

    struct Storage {
        mapping(address PT => OracleData) priceOracle;
        mapping(address PT => uint256) totalPT;
        mapping(address user => bool) isWhitelisted;
    }

    function $() internal pure returns (Storage storage res) {
        assembly ("memory-safe") {
            res.slot := STORAGE_SLOT
        }
    }

    function priceOracle(address PT)
        public
        view
        returns (bool isPaused, IPChainlinkOracleEssential oracle, uint256 multiplier)
    {
        OracleData memory data = $().priceOracle[PT];
        isPaused = data.isPaused;
        oracle = IPChainlinkOracleEssential(data.oracle);
        multiplier = data.multiplier;

        require(address(oracle) != address(0), "FixedPricePTAMMV2: oracle not set");
    }

    function totalPt(address PT) external view returns (uint256) {
        return $().totalPT[PT];
    }

    function isWhitelisted(address user) external view returns (bool) {
        return $().isWhitelisted[user];
    }

    function previewSwapExactPtForToken(address PT, uint256 exactPtIn) public view returns (uint256 amountTokenOut) {
        (bool isPaused, IPChainlinkOracleEssential oracle, uint256 multiplier) = priceOracle(PT);
        require(!isPaused, "FixedPricePTAMMV2: trading paused");

        (, int256 rawPrice,,,) = oracle.latestRoundData();

        // exactPtIn * rawPrice * multiplier
        return (exactPtIn * rawPrice.Uint() * multiplier) / (PMath.ONE * PMath.ONE);
    }

    function swapExactPtForToken(address receiver, address PT, uint256 exactPtIn, bytes calldata data)
        external
        nonReentrant
        returns (uint256 netTokenOut)
    {
        netTokenOut = previewSwapExactPtForToken(PT, exactPtIn);

        _transferOut(outputToken, receiver, netTokenOut);

        if (data.length > 0) {
            IPFixedPricePTAMMSwapCallback(msg.sender).swapCallback(netTokenOut, exactPtIn, data);
        }

        $().totalPT[PT] += exactPtIn;
        require(_selfBalance(PT) >= $().totalPT[PT], "FixedPricePTAMMV2: insufficient PT received");

        emit Swap(msg.sender, receiver, PT, exactPtIn, netTokenOut);
    }

    // Add/remove funds

    modifier onlyWhitelisted() {
        require($().isWhitelisted[msg.sender], "FixedPricePTAMMV2: Not whitelisted");
        _;
    }

    function addFundWhitelisted(uint256 amount) external onlyWhitelisted nonReentrant {
        _transferIn(outputToken, msg.sender, amount);
        _mint(msg.sender, amount);
        emit TokenFunded(msg.sender, amount);
    }

    function removeFund(uint256 amount) external nonReentrant {
        _burn(msg.sender, amount);
        _transferOut(outputToken, msg.sender, amount);
        emit TokenWithdrawn(msg.sender, amount);
    }

    // Admin functions

    function withdrawPt(address PT, uint256 amount) external onlyOwner {
        _transferOut(PT, msg.sender, amount);
        $().totalPT[PT] -= amount;
    }

    function setWhitelist(address user, bool isWhitelisted_) external onlyOwner {
        $().isWhitelisted[user] = isWhitelisted_;
        emit WhitelistUpdated(user, isWhitelisted_);
    }

    function setPriceOracle(address PT, address _priceOracle, uint256 _multiplier) external onlyOwner {
        $().priceOracle[PT].oracle = _priceOracle;
        $().priceOracle[PT].multiplier = _multiplier;
        emit PriceOracleUpdated(PT, _priceOracle);
    }

    function setPausePtTrading(address PT, bool isPaused) external onlyOwner {
        $().priceOracle[PT].isPaused = isPaused;
        emit PauseStatusUpdated(PT, isPaused);
    }
}
