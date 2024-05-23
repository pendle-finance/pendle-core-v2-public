// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "../../SYBase.sol";
import "../../../../interfaces/Dolomite/IDolomiteMarginProxy.sol";
import "../../../../interfaces/Dolomite/IDolomiteMarginContract.sol";

contract PendleDolomiteSY is SYBase {
    address public immutable asset;
    uint256 public immutable marketId;
    address public immutable marginProxy;
    address public immutable marginContract;

    constructor(
        string memory _name,
        string memory _symbol,
        address _asset,
        address _marginProxy,
        address _marginContract
    ) SYBase(_name, _symbol, _asset) {
        asset = _asset;
        marketId = IDolomiteMarginContract(_marginContract).getMarketIdByTokenAddress(asset);
        marginProxy = _marginProxy;
        marginContract = _marginContract;
        _safeApproveInf(asset, marginContract);
    }

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(
        address /*tokenIn*/,
        uint256 amountDeposited
    ) internal override returns (uint256 /*amountSharesOut*/) {
        uint256 preBal = _getOwningShares();
        IDolomiteMarginProxy(marginProxy).depositWeiIntoDefaultAccount(marketId, amountDeposited);
        return _getOwningShares() - preBal;
    }

    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal override returns (uint256 amountTokenOut) {
        uint256 preBal = _selfBalance(asset);
        IDolomiteMarginProxy(marginProxy).withdrawParFromDefaultAccount(
            marketId,
            amountSharesToRedeem,
            IDolomiteMarginProxy.BalanceCheckFlag.None
        );

        amountTokenOut = _selfBalance(asset) - preBal;
        _transferOut(asset, receiver, amountTokenOut);
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

    function _previewDeposit(
        address /*tokenIn*/,
        uint256 amountTokenToDeposit
    ) internal view override returns (uint256) {
        uint256 index = _getDolomiteCurrentSupplyIndex();
        return (amountTokenToDeposit * PMath.ONE) / index;
    }

    function _previewRedeem(
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal view override returns (uint256) {
        uint256 index = _getDolomiteCurrentSupplyIndex();
        return (amountSharesToRedeem * index) / PMath.ONE;
    }

    function getTokensIn() public view override returns (address[] memory res) {
        return ArrayLib.create(asset);
    }

    function getTokensOut() public view override returns (address[] memory res) {
        return ArrayLib.create(asset);
    }

    function isValidTokenIn(address token) public view override returns (bool) {
        return token == asset;
    }

    function isValidTokenOut(address token) public view override returns (bool) {
        return token == asset;
    }

    function assetInfo() external view override returns (AssetType, address, uint8) {
        return (AssetType.TOKEN, address(asset), IERC20Metadata(asset).decimals());
    }

    /*///////////////////////////////////////////////////////////////
                            DOLOMITE HELPER
    //////////////////////////////////////////////////////////////*/

    // 1 share = 1 dolomite par
    function _getOwningShares() internal view returns (uint256) {
        IDolomiteMarginContract.Wei memory accountPar = IDolomiteMarginContract(marginContract).getAccountPar(
            _getDefaultAccountInfo(),
            marketId
        );
        return accountPar.value;
    }

    function _getDefaultAccountInfo() internal view returns (IDolomiteMarginContract.Info memory account) {
        account.owner = address(this);
        account.number = 0;
    }
}
