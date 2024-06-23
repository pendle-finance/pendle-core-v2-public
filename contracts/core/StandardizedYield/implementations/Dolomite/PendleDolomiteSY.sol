// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "../../SYBase.sol";
import "../../../../interfaces/Dolomite/IDolomiteMarginContract.sol";
import "../../../../interfaces/Dolomite/IDolomiteDToken.sol";

contract PendleDolomiteSY is SYBase {
    // solhint-disable immutable-vars-naming
    address public immutable asset;
    uint256 public immutable marketId;
    address public immutable marginContract;
    address public immutable dToken;

    constructor(string memory _name, string memory _symbol, address _dToken) SYBase(_name, _symbol, _dToken) {
        asset = IDolomiteDToken(_dToken).underlyingToken();
        marketId = IDolomiteDToken(_dToken).marketId();
        marginContract = IDolomiteDToken(_dToken).DOLOMITE_MARGIN();
        dToken = _dToken;
        _safeApproveInf(asset, marginContract);
    }

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == dToken) {
            return amountDeposited;
        }
        return IDolomiteDToken(dToken).mint(amountDeposited);
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal override returns (uint256 amountTokenOut) {
        if (tokenOut == dToken) {
            amountTokenOut = amountSharesToRedeem;
        } else {
            amountTokenOut = IDolomiteDToken(dToken).redeem(amountSharesToRedeem);
        }
        _transferOut(tokenOut, receiver, amountTokenOut);
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view override returns (uint256) {
        return _getDolomiteCurrentSupplyIndex();
    }

    function _getDolomiteCurrentSupplyIndex() internal view returns (uint256) {
        IDolomiteMarginContract.Index memory dolomiteIndex = IDolomiteMarginContract(marginContract)
            .getMarketCurrentIndex(marketId);
        return dolomiteIndex.supply;
    }

    /*///////////////////////////////////////////////////////////////
                        MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit) internal view override returns (uint256) {
        if (tokenIn == dToken) {
            return amountTokenToDeposit;
        }
        uint256 index = _getDolomiteCurrentSupplyIndex();
        return (amountTokenToDeposit * PMath.ONE) / index;
    }

    function _previewRedeem(address tokenOut, uint256 amountSharesToRedeem) internal view override returns (uint256) {
        if (tokenOut == dToken) {
            return amountSharesToRedeem;
        }
        uint256 index = _getDolomiteCurrentSupplyIndex();
        return (amountSharesToRedeem * index) / PMath.ONE;
    }

    function getTokensIn() public view override returns (address[] memory res) {
        return ArrayLib.create(asset, dToken);
    }

    function getTokensOut() public view override returns (address[] memory res) {
        return ArrayLib.create(asset, dToken);
    }

    function isValidTokenIn(address token) public view override returns (bool) {
        return token == asset || token == dToken;
    }

    function isValidTokenOut(address token) public view override returns (bool) {
        return token == asset || token == dToken;
    }

    function assetInfo() external view override returns (AssetType, address, uint8) {
        return (AssetType.TOKEN, address(asset), IERC20Metadata(asset).decimals());
    }
}
