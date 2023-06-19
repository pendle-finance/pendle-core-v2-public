// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../SYBase.sol";
import "../../../interfaces/BinanceEth/IWBETH.sol";

contract PendleBinanceEth is SYBase {
    using Math for uint256;

    address public immutable eth;
    address public immutable wbeth;

    constructor(
        string memory _name,
        string memory _symbol,
        address _eth,
        address _wbeth
    ) SYBase(_name, _symbol, _wbeth) {
        eth = _eth;
        wbeth = _wbeth;
        _safeApproveInf(eth, wbeth);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal override returns (uint256 amountSharesOut) {
        if (tokenIn == eth) {
            uint256 previousBalance = _selfBalance(wbeth);
            IWBETH(wbeth).deposit(amountDeposited, address(this));
            amountSharesOut = _selfBalance(wbeth) - previousBalance;
        } else {
            // wbeth
            amountSharesOut = amountDeposited;
        }
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal override returns (uint256 /*amountTokenOut*/) {
        _transferOut(tokenOut, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view override returns (uint256) {
        // exchangeRate is set by wbeth's oracle
        return IWBETH(wbeth).exchangeRate();
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == eth) {
            return amountTokenToDeposit.divDown(exchangeRate());
        } else {
            return amountTokenToDeposit;
        }
    }

    function _previewRedeem(
        address,
        uint256 amountSharesToRedeem
    ) internal pure override returns (uint256 /*amountTokenOut*/) {
        return amountSharesToRedeem;
    }

    function getTokensIn() public view override returns (address[] memory res) {
        res = new address[](2);
        res[0] = wbeth;
        res[1] = eth;
    }

    function getTokensOut() public view override returns (address[] memory res) {
        res = new address[](1);
        res[0] = wbeth;
    }

    function isValidTokenIn(address token) public view override returns (bool) {
        return token == eth || token == wbeth;
    }

    function isValidTokenOut(address token) public view override returns (bool) {
        return token == wbeth;
    }

    function assetInfo()
        external
        view
        returns (AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (AssetType.TOKEN, eth, 18);
    }
}
