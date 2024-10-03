// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./PendleCornBaseSYUpg.sol";
import "../../../../interfaces/Bedrock/IBedrockUniBTCVault.sol";

contract PendleCornUniBTCSYUpg is PendleCornBaseSYUpg {
    // solhint-disable immutable-vars-naming
    // solhint-disable const-name-snakecase
    address public constant VAULT = 0x047D41F2544B7F63A8e991aF2068a363d210d6Da;
    address public constant UNIBTC = 0x004E9C3EF86bc1ca1f0bB5C7662861Ee93350568;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant FBTC = 0xC96dE26018A54D51c097160568752c4E3BD6C364;
    address public constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    // end contract, no gaps needed

    constructor() PendleCornBaseSYUpg(UNIBTC, WBTC) {
        _disableInitializers();
    }

    function initialize(address _initialExchangeRateOracle) external initializer {
        _safeApproveInf(WBTC, VAULT);
        _safeApproveInf(FBTC, VAULT);
        _safeApproveInf(CBBTC, VAULT);
        __CornBaseSY_init_("SY Corn Bedrock uniBTC", "SY-corn-uniBTC", _initialExchangeRateOracle);
    }

    function approveForVault(address token) external onlyOwner {
        _safeApproveInf(token, VAULT);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn != UNIBTC) {
            uint256 preBalance = _selfBalance(UNIBTC);
            IBedrockUniBTCVault(VAULT).mint(tokenIn, amountDeposited);
            amountDeposited = _selfBalance(UNIBTC) - preBalance;
        }
        return ICornSilo(CORN_SILO).deposit(depositToken, amountDeposited);
    }

    // preview deposit should still work as amountDeposited = amountSharesOut for all tokens

    function getTokensIn() public view virtual override returns (address[] memory) {
        return ArrayLib.create(WBTC, FBTC, CBBTC, depositToken);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == WBTC || token == FBTC || token == CBBTC || token == depositToken;
    }
}
