// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;
import "../../SYBase.sol";
import "../../../../interfaces/Swell/IRswETH.sol";

contract PendleRswETHSY is SYBase {
    using PMath for uint256;

    address public immutable swETH;
    address public immutable referral;

    constructor(
        string memory _name,
        string memory _symbol,
        address _swETH,
        address _referral
    ) SYBase(_name, _symbol, _swETH) {
        swETH = _swETH;
        referral = _referral;
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == NATIVE) {
            uint256 preBalance = _selfBalance(swETH);
            IRswETH(swETH).depositWithReferral{value: amountDeposited}(referral);
            return _selfBalance(swETH) - preBalance;
        } else {
            // sweth
            return amountDeposited;
        }
    }

    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 /*amountTokenOut*/) {
        _transferOut(swETH, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return IRswETH(swETH).getRate();
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == NATIVE) {
            return amountTokenToDeposit.divDown(IRswETH(swETH).getRate());
        } else {
            return amountTokenToDeposit;
        }
    }

    function _previewRedeem(
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal pure override returns (uint256 /*amountTokenOut*/) {
        return amountSharesToRedeem;
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = swETH;
        res[1] = NATIVE;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](1);
        res[0] = swETH;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == NATIVE || token == swETH;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == swETH;
    }

    function assetInfo() external pure returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, NATIVE, 18);
    }
}
