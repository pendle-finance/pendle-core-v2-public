// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../SYBaseWithRewards.sol";
import "./PendleVTokenRateHelper.sol";
import "../../../../interfaces/Venus/IVenusBNB.sol";
import "../../../../interfaces/Venus/IVenusComptroller.sol";

contract PendleVenusBNBSY is SYBaseWithRewards, PendleVTokenRateHelper {
    using PMath for uint256;

    error VenusError(uint256 errorCode);

    address public constant VBNB = 0xA07c5b74C9B40447a954e1466938b865b6BBea36;
    address public constant XVS = 0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63;
    address public constant COMPTROLLER = 0xfD36E2c2a6789Db23113685031d7F16329158384;
    uint256 public constant INITIAL_EXCHANGE_RATE = 2 * 10 ** 26;

    constructor()
        SYBaseWithRewards("SY Venus BNB", "SY-vBNB", VBNB)
        PendleVTokenRateHelper(VBNB, INITIAL_EXCHANGE_RATE)
    {}

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address tokenIn, uint256 amountDeposited) internal virtual override returns (uint256) {
        if (tokenIn == VBNB) {
            return amountDeposited;
        } else {
            uint256 preBalance = _selfBalance(VBNB);
            IVenusBNB(VBNB).mint{value: amountDeposited}(); // alr reverts on error
            return _selfBalance(VBNB) - preBalance;
        }
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        if (tokenOut == VBNB) {
            _transferOut(VBNB, receiver, amountTokenOut = amountSharesToRedeem);
        } else {
            uint256 err = IVenusBNB(VBNB).redeem(amountSharesToRedeem);
            if (err != 0) {
                revert VenusError(err);
            }
            _transferOut(NATIVE, receiver, amountTokenOut = _selfBalance(NATIVE));
        }
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return _exchangeRateCurrentView();
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    function _getRewardTokens() internal pure override returns (address[] memory res) {
        return ArrayLib.create(XVS);
    }

    function _redeemExternalReward() internal override {
        IVenusComptroller(COMPTROLLER).claimVenus(address(this), ArrayLib.create(VBNB));
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit) internal view override returns (uint256) {
        if (tokenIn == VBNB) {
            return amountTokenToDeposit;
        }
        uint256 rate = _exchangeRateCurrentView();
        return amountTokenToDeposit.divDown(rate);
    }

    function _previewRedeem(
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal view override returns (uint256 amountTokenOut) {
        if (tokenOut == VBNB) {
            return amountSharesToRedeem;
        }
        uint256 rate = _exchangeRateCurrentView();
        return amountSharesToRedeem.mulDown(rate);
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        return ArrayLib.create(NATIVE, VBNB);
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        return ArrayLib.create(NATIVE, VBNB);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == NATIVE || token == VBNB;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == NATIVE || token == VBNB;
    }

    function assetInfo() external pure returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, NATIVE, 18);
    }
}
