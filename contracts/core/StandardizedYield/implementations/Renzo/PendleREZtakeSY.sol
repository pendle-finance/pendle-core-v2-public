// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../SYBase.sol";
import "../../../../interfaces/Renzo/IRenzoReztake.sol";

contract PendleREZtakeSY is SYBase {
    // solhint-disable const-name-snakecase
    address public constant ztake = 0x1736011D3E075351B319DBC1da28Dac68Ea830A6;
    address public constant rez = 0x3B50805453023a91a8bf641e279401a0b23FA6F9;

    constructor() SYBase("SY Renzo REZ Staking", "SY-REZtake", rez) {
        _safeApproveInf(rez, ztake);
    }

    function _deposit(address /*tokenIn*/, uint256 amountDeposited) internal virtual override returns (uint256) {
        IRenzoReztake(ztake).stake(amountDeposited);
        return amountDeposited;
    }

    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256) {
        IRenzoReztake(ztake).unStake(amountSharesToRedeem);
        IRenzoReztake(ztake).claim(0);
        _transferOut(rez, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return PMath.ONE;
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address /*tokenIn*/,
        uint256 amountTokenToDeposit
    ) internal pure override returns (uint256 amountSharesOut) {
        return amountTokenToDeposit;
    }

    function _previewRedeem(
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal pure override returns (uint256 amountTokenOut) {
        return amountSharesToRedeem;
    }

    function getTokensIn() public view virtual override returns (address[] memory) {
        return ArrayLib.create(rez);
    }

    function getTokensOut() public view virtual override returns (address[] memory) {
        return ArrayLib.create(rez);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == rez;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == rez;
    }

    function assetInfo() external pure returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, rez, 18);
    }
}
