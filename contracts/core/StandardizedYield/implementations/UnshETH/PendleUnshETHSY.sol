// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;
import "../../SYBase.sol";
import "../../../../interfaces/UnshETH/IUnshETH.sol";
import "../../../../interfaces/UnshETH/ILSDVault.sol";
import "../../../../interfaces/UnshETH/IUnshETHZap.sol";

contract UnshETHSY is SYBase {
    using PMath for uint256;

    address public immutable unshETH;
    address public unshETHZap;
    address public immutable LSDVault; 
    //TODO: get unshETHZapAddress from LSDVault

    constructor(
        string memory _name,
        string memory _symbol,
        address _unshETH
    ) SYBase(_name, _symbol, _unshETH) {
        unshETH = _unshETH;
    }

    function unshETHZapAddress() internal view returns (address) {
        //
        return ILSDVault.unshETHZapAddress();
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == NATIVE) {
            uint256 preBalance = _selfBalance(unshETH);
            IUnshETHZap(unshETHZap).mint_unsheth_with_eth(amountDeposited, 7);
            //TODO: we can't just hardcode a pathID in here
            //will probably need to create a helper contract to return the correct path ID here

            return _selfBalance(unshETH) - preBalance;
        } else {
            return amountDeposited;
        }
    }

    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 /*amountTokenOut*/) {
        _transferOut(unshETH, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        //return price of unshETH  
        return ILSDVault(LSDVault).stakedETHperunshETH();
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == NATIVE) {
            //return the amount based on stakedETHPerUnshETH
            return amountTokenToDeposit.divDown(exchangeRate());
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
        //TODO: should this technically include all tokens supported by unshETHZap/LSDVault? 
        res[0] = unshETH;
        res[1] = NATIVE;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](1);
        res[0] = unshETH;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == NATIVE || token == unshETH;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == unshETH;
    }

    function assetInfo()
        external
        pure
        returns (AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (AssetType.TOKEN, NATIVE, 18);
    }
}
