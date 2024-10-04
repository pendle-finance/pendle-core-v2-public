// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;
import "../../SYBase.sol";
import "../../../../interfaces/Usual/IUsualUSD0PP.sol";

contract PendleUsualUSD0PPSY is SYBase {
    address public constant USD0PP = 0x35D8949372D46B7a3D5A56006AE77B215fc69bC0;
    address public constant USD0 = 0x73A15FeD60Bf67631dC6cd7Bc5B6e8da8190aCF5;

    constructor() SYBase("SY USD0++", "SY-USD0++", USD0PP) {
        _safeApproveInf(USD0, USD0PP);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == USD0) {
            IUsualUSD0PP(USD0PP).mint(amountDeposited);
        }
        return amountDeposited;
    }

    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal override returns (uint256) {
        _transferOut(yieldToken, receiver, amountSharesToRedeem);
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
        return ArrayLib.create(USD0PP, USD0);
    }

    function getTokensOut() public pure override returns (address[] memory res) {
        return ArrayLib.create(USD0PP);
    }

    function isValidTokenIn(address token) public pure override returns (bool) {
        return token == USD0PP || token == USD0;
    }

    function isValidTokenOut(address token) public pure override returns (bool) {
        return token == USD0PP;
    }

    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, USD0PP, IERC20Metadata(USD0PP).decimals());
    }
}
