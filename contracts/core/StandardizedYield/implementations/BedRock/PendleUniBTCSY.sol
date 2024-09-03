// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../SYBase.sol";
import "../../../../interfaces/Bedrock/IBedrockUniBTCVault.sol";

contract PendleUniBTCSY is SYBase {
    address public constant VAULT = 0x047D41F2544B7F63A8e991aF2068a363d210d6Da;
    address public constant UNIBTC = 0x004E9C3EF86bc1ca1f0bB5C7662861Ee93350568;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant FBTC = 0xC96dE26018A54D51c097160568752c4E3BD6C364;

    constructor() SYBase("SY Bedrock uniBTC", "SY-uniBTC", UNIBTC) {
        _safeApproveInf(WBTC, VAULT);
        _safeApproveInf(FBTC, VAULT);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn != UNIBTC) {
            uint256 preBalance = _selfBalance(UNIBTC);
            IBedrockUniBTCVault(VAULT).mint(tokenIn, amountDeposited);
            return _selfBalance(UNIBTC) - preBalance;
        }
        return amountDeposited; /// (WBTC & FBTC both have 8 decimals)
    }

    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal override returns (uint256) {
        _transferOut(UNIBTC, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
    }

    function exchangeRate() public view virtual override returns (uint256 res) {
        return PMath.ONE;
    }

    function _previewDeposit(
        address /*tokenIn*/,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 /*amountSharesOut*/) {
        return amountTokenToDeposit;
    }

    function _previewRedeem(
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal view virtual override returns (uint256 /*amountTokenOut*/) {
        return amountSharesToRedeem;
    }

    function getTokensIn() public pure override returns (address[] memory res) {
        return ArrayLib.create(WBTC, FBTC, UNIBTC);
    }

    function getTokensOut() public pure override returns (address[] memory res) {
        return ArrayLib.create(UNIBTC);
    }

    function isValidTokenIn(address token) public pure override returns (bool) {
        return token == WBTC || token == FBTC || token == UNIBTC;
    }

    function isValidTokenOut(address token) public pure override returns (bool) {
        return token == UNIBTC;
    }

    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, UNIBTC, IERC20Metadata(UNIBTC).decimals());
    }
}
