// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "../router/base/ActionBase.sol";
import "../interfaces/IPActionMiscV3.sol";
import "../interfaces/IPReflector.sol";
import "../core/libraries/BoringOwnableUpgradeableV2.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract ExpiredLpPtRedeemer is TokenHelper, ReentrancyGuardUpgradeable, BoringOwnableUpgradeableV2, UUPSUpgradeable {
    mapping(address => bool) public whitelistedMarkets;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) public initializer {
        __BoringOwnableV2_init(_owner);
        __ReentrancyGuard_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function exitPostExpToToken(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 netLpIn,
        address tokenRedeemSy,
        uint256 minTokenOut
    ) external nonReentrant returns (uint256 totalTokenOut) {
        require(whitelistedMarkets[market], "n/a");

        (IStandardizedYield SY, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();

        IPMarket(market).redeemRewards(msg.sender);

        uint256 totalSyRedeem = 0;
        uint256 totalPtRedeem = 0;

        if (netPtIn > 0) {
            _transferFrom(PT, msg.sender, address(this), netLpIn);
            totalPtRedeem += netPtIn;
        }

        if (netLpIn > 0) {
            _transferFrom(IERC20(market), msg.sender, market, netLpIn);
            (uint256 netSyFromRemove, uint256 netPtFromRemove) = IPMarket(market).burn(
                address(this),
                address(this),
                netLpIn
            );

            totalSyRedeem += netSyFromRemove;
            totalPtRedeem += netPtFromRemove;
        }

        uint256 netSyFromPt = SYUtils.assetToSy(YT.pyIndexCurrent(), totalPtRedeem);
        totalSyRedeem += netSyFromPt;

        {
            _transferOut(address(SY), address(SY), totalSyRedeem);
            totalTokenOut = IStandardizedYield(SY).redeem(receiver, totalSyRedeem, tokenRedeemSy, minTokenOut, true);
        }
    }

    function setWhitelistedMarket(address[] calldata markets, bool isWhitelisted) external onlyOwner {
        for (uint256 i = 0; i < markets.length; i++) {
            require(IPMarket(markets[i]).isExpired(), "not expired");
            whitelistedMarkets[markets[i]] = isWhitelisted;
        }
    }

    function withdraw(address[] memory tokens) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            _transferOut(tokens[i], msg.sender, _selfBalance(tokens[i]));
        }
    }
}
