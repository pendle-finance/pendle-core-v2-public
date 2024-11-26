// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../SYBaseUpg.sol";
import "../../../../interfaces/IPTokenWithSupplyCap.sol";
import "../../../../interfaces/IPExchangeRateOracle.sol";
import "../../../../interfaces/Lombard/ILBTCMinterBase.sol";

contract PendleLBTCBaseSY is SYBaseUpg, IPTokenWithSupplyCap {
    event SetNewExchangeRateOracle(address oracle);

    address public exchangeRateOracle;

    // solhint-disable immutable-vars-naming
    // solhint-disable const-name-snakecase
    address public constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address public constant LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;
    address public constant MINTER = 0x92c01FC0F59857c6E920EdFf1139904b2Bb74c7c;
    uint256 public constant MINTER_MAX_COMISSION = 10000;

    constructor() SYBaseUpg(LBTC) {}

    function initialize(address _initialOracle) external initializer {
        __SYBaseUpg_init("SY Lombard LBTC", "SY-LBTC");
        _safeApproveInf(CBBTC, MINTER);
        _setExchangeRateOracle(_initialOracle);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == LBTC) return amountDeposited;

        uint256 preBalance = _selfBalance(LBTC);
        ILBTCMinterBase(MINTER).swapCBBTCToLBTC(amountDeposited);
        return _selfBalance(LBTC) - preBalance;
    }

    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal override returns (uint256) {
        _transferOut(LBTC, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return IPExchangeRateOracle(exchangeRateOracle).getExchangeRate();
    }

    function setExchangeRateOracle(address newOracle) external virtual onlyOwner {
        _setExchangeRateOracle(newOracle);
    }

    function _setExchangeRateOracle(address newOracle) internal virtual {
        exchangeRateOracle = newOracle;
        emit SetNewExchangeRateOracle(newOracle);
    }

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == LBTC) return amountTokenToDeposit;

        uint256 feeRate = ILBTCMinterBase(MINTER).relativeFee();
        uint256 feeAmount = PMath.rawDivUp(amountTokenToDeposit * feeRate, MINTER_MAX_COMISSION);
        return amountTokenToDeposit - feeAmount;
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewRedeem(
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal pure override returns (uint256 /*amountTokenOut*/) {
        return amountSharesToRedeem;
    }

    function getTokensIn() public pure override returns (address[] memory res) {
        return ArrayLib.create(CBBTC, LBTC);
    }

    function getTokensOut() public pure override returns (address[] memory res) {
        return ArrayLib.create(LBTC);
    }

    function isValidTokenIn(address token) public pure override returns (bool) {
        return token == CBBTC || token == LBTC;
    }

    function isValidTokenOut(address token) public pure override returns (bool) {
        return token == LBTC;
    }

    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, CBBTC, IERC20Metadata(CBBTC).decimals());
    }

    function getAbsoluteTotalSupply() external view returns (uint256) {
        // to be upgraded by Lombard to expose totalStake variable
        // this function fails/be inaccurate when stakeLimit is lowered to be smaller than remaining stake
        return ILBTCMinterBase(MINTER).stakeLimit() - ILBTCMinterBase(MINTER).remainingStake();
    }
    
    function getAbsoluteSupplyCap() external view returns (uint256) {
        return ILBTCMinterBase(MINTER).stakeLimit();
    }
}
