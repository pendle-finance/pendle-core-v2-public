// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendleSwellStakingERC20SY.sol";
import "../../../../interfaces/Swell/IRswETH.sol";

contract PendleSwellRswETHStakingSY is PendleSwellStakingERC20SY {
    using PMath for uint256;

    address public constant REFERRAL = 0x8119EC16F0573B7dAc7C0CB94EB504FB32456ee1;
    address public constant RSWETH = 0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0;

    constructor() PendleSwellStakingERC20SY("SY Swell L2 Deposit RswETH", "SY-sw2Rsweth", RSWETH) {}

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/
    function exchangeRate() public view virtual override returns (uint256) {
        return IRswETH(RSWETH).getRate();
    }

    /*///////////////////////////////////////////////////////////////
                    ADDITIONAL TOKEN IN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getAdditionalTokens() internal view virtual override returns (address[] memory) {
        return ArrayLib.create(NATIVE);
    }

    function _previewToStakeToken(
        address,
        uint256 amountNativeToDeposit
    ) internal view virtual override returns (uint256) {
        return amountNativeToDeposit.divDown(IRswETH(RSWETH).getRate());
    }

    function _wrapToStakeToken(address, uint256 amountNativeToDeposit) internal virtual override returns (uint256) {
        uint256 preBalance = _selfBalance(RSWETH);
        IRswETH(RSWETH).depositWithReferral{value: amountNativeToDeposit}(REFERRAL);
        return _selfBalance(RSWETH) - preBalance;
    }

    function _canWrapToStakeToken(address token) internal view virtual override returns (bool) {
        return token == NATIVE;
    }

    function assetInfo()
        external
        view
        virtual
        override
        returns (AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (AssetType.TOKEN, NATIVE, 18);
    }
}
