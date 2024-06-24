// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../SYBaseUpg.sol";
import "../../../../interfaces/Tensorplex/ITensorplexStTAO.sol";

// wTAO can be modified on stTAO contract on very unlikely special occasions.
// However in such case, depositing using stTAO should still be feasible so making wTAO address mutable is not worth the gas cost of users.

// @notice: stTAO and wstTAO is the same one.
// Tensorplex use wstTAO for naming convention on contract writing and stTAO for the name of the token

contract PendleStTAOSY is SYBaseUpg {
    using PMath for uint256;

    error MaxStTAOSupplyExceeded(uint256 amountTaoToWrap, uint256 maxTaoForWrap);

    // solhint-disable immutable-vars-naming
    address public immutable stTAO;
    address public immutable wTAO;

    constructor(address _stTAO) SYBaseUpg(_stTAO) {
        _disableInitializers();
        stTAO = _stTAO;
        wTAO = ITensorplexStTAO(stTAO).wrappedToken();
    }

    function initialize() external initializer {
        __SYBaseUpg_init("SY Tensorplex Staked TAO", "SY-stTAO");
        _safeApproveInf(wTAO, stTAO);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address tokenIn, uint256 amountDeposited) internal virtual override returns (uint256) {
        if (tokenIn == stTAO) {
            return amountDeposited;
        }
        uint256 preBalance = _selfBalance(stTAO);
        ITensorplexStTAO(stTAO).wrap(amountDeposited);
        return _selfBalance(stTAO) - preBalance;
    }

    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256) {
        _transferOut(stTAO, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/
    function exchangeRate() public view virtual override returns (uint256) {
        return PMath.ONE.divDown(ITensorplexStTAO(stTAO).exchangeRate());
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit) internal view override returns (uint256) {
        if (tokenIn == stTAO) {
            return amountTokenToDeposit;
        }

        uint256 maxTaoForWrap = ITensorplexStTAO(stTAO).maxTaoForWrap();
        if (amountTokenToDeposit > maxTaoForWrap) {
            revert MaxStTAOSupplyExceeded(amountTokenToDeposit, maxTaoForWrap);
        }

        (uint256 amountWTaoAfterFee, ) = ITensorplexStTAO(stTAO).calculateAmtAfterFee(amountTokenToDeposit);
        return ITensorplexStTAO(stTAO).getWstTAObyWTAO(amountWTaoAfterFee);
    }

    function _previewRedeem(
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal pure override returns (uint256 /*amountTokenOut*/) {
        return amountSharesToRedeem;
    }

    function getTokensIn() public view virtual override returns (address[] memory) {
        return ArrayLib.create(wTAO, stTAO);
    }

    function getTokensOut() public view virtual override returns (address[] memory) {
        return ArrayLib.create(stTAO);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == wTAO || token == stTAO;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == stTAO;
    }

    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, wTAO, IERC20Metadata(wTAO).decimals());
    }
}
