// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../base-implementations/SCYBaseWithRewards.sol";
import "../../../interfaces/IQiErc20.sol";
import "../../../interfaces/IQiAvax.sol";
import "../../../interfaces/IBenQiComptroller.sol";
import "../../../interfaces/IWAvax.sol";
import "../../../interfaces/ISAvax.sol";

import "./PendleQiTokenHelper.sol";

contract PendleQiSAvaxSCY is SCYBaseWithRewards, PendleQiTokenHelper {
    address public immutable QI;
    address public immutable WAVAX;
    address public immutable comptroller;

    address public immutable SAVAX;
    address public immutable QI_SAVAX;

    constructor(
        string memory _name,
        string memory _symbol,
        address _qiSAvax,
        address _WAVAX,
        uint256 _initialExchangeRateMantissa
    )
        SCYBaseWithRewards(_name, _symbol, _qiSAvax)
        PendleQiTokenHelper(_qiSAvax, _initialExchangeRateMantissa)
    {
        require(_qiSAvax != address(0), "zero address");
        require(_WAVAX != address(0), "zero address");

        QI_SAVAX = _qiSAvax;
        WAVAX = _WAVAX;

        SAVAX = IQiErc20(QI_SAVAX).underlying();
        comptroller = IQiToken(_qiSAvax).comptroller();

        QI = IBenQiComptroller(comptroller).qiAddress();

        _safeApprove(SAVAX, QI_SAVAX, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {SCYBase-_deposit}
     *
     * The underlying yield token is qiToken (qiSAvax). Tokens allowed for deposit are sAvax, qiSAvax, AVAX, WAVAX.
     *
     *If  the base token deposited is underlying asset, the function first convert those deposited SAvax into qiSAvax. Then the corresponding amount of shares is returned.
     *
     * If the base token is AVAX, it will swap to SAvax which will then be deposited to QiSAvax.
     *
     * If the base token is WAVAX, it will unwrap to AVAX, then swap to SAvax which will be deposited to mint QiSAvax.
     *
     * The exchange rate of qiToken (qiSAvax) to shares is 1:1
     */
    function _deposit(address tokenIn, uint256 amountDeposited)
        internal
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == QI_SAVAX) {
            amountSharesOut = amountDeposited;
        } else if (tokenIn == WAVAX || tokenIn == NATIVE) {
            // If 'tokenIn' is WAVAX or NATIVE
            if (tokenIn == WAVAX) {
                // Unwrap WAVAX into Native Avax token first
                IWAvax(WAVAX).withdraw(amountDeposited);
            }

            // Swap AVAX for SAVAX (regardless from AVAX directly or unwrapped from WAVAX), note since exchange rate of AVAX to SAVAX is NOT 1:1, retrieve amount of SAvax received after depositing NATIVE.
            uint256 sAvaxToMintQiSAvaxAmount = ISAvax(tokenIn).submit{ value: amountDeposited }();

            // Deposit (WAVAX or NATIVE) converted sAvax into BenQi.
            amountSharesOut = _depositUnderlyingIntoBenQi(sAvaxToMintQiSAvaxAmount);
        } else {
            // If token deposited is sAvax, it will directly mint qiSAvax from BenQi using amountDeposited
            amountSharesOut = _depositUnderlyingIntoBenQi(amountDeposited);
        }
    }

    /**
     * @dev Deposits underlying token (sAvax) into BenQi and returns the amount of qiSAvax or shares (since qiSAvax : shares == 1:1).
     */
    function _depositUnderlyingIntoBenQi(uint256 amountDeposited)
        internal
        returns (uint256 amountSharesDeposited)
    {
        IQiErc20 QiSAvax = IQiErc20(QI_SAVAX);

        uint256 preBalanceQiSAvax = QiSAvax.balanceOf(address(this));

        uint256 errCode = QiSAvax.mint(amountDeposited);
        require(errCode == 0, "mint failed");

        amountSharesDeposited = QiSAvax.balanceOf(address(this)) - preBalanceQiSAvax;
    }

    /**
     * @dev See {SCYBase-_redeem}
     *
     * The shares are redeemed into the same amount of qiTokens (qiSAvax). If `tokenOut` is the underlying asset sAvax.
     *
     * Only SAvax or QiSAvax can be withdrawn.
     *
     * the function also redeems said asset from the corresponding amount of qiToken (qiSAvax).
     */
    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == QI_SAVAX) {
            amountTokenOut = amountSharesToRedeem;
        } else {
            uint256 preBalanceUnderlying = _selfBalance(SAVAX);

            uint256 errCode = IQiErc20(QI_SAVAX).redeem(amountSharesToRedeem);
            require(errCode == 0, "redeem failed");

            // Even though underlying is not rewardToken, we still manually check balance for accounting purposes.
            amountTokenOut = _selfBalance(SAVAX) - preBalanceUnderlying;
        }
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates and updates the exchange rate of shares to underlying asset token
     * @dev It is the exchange rate of qiSAvax to native Avax token, this is calculated from sAvax to QiSAvax Exchange rate and then followed by converting that exchange rate relative to native Avax exchange rate.
     */
    function exchangeRate() public view override returns (uint256) {
        uint256 qiSAvaxToSAvaxExchangeRate = _exchangeRateCurrentView();
        return ISAvax(SAVAX).getPooledAvaxByShares(qiSAvaxToSAvaxExchangeRate);
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-getRewardTokens}
     */
    function _getRewardTokens() internal view override returns (address[] memory res) {
        res = new address[](2);
        res[0] = QI;
        res[1] = WAVAX;
    }

    function _redeemExternalReward() internal override {
        address[] memory holders = new address[](1);
        address[] memory qiTokens = new address[](1);
        holders[0] = address(this);
        qiTokens[0] = QI_SAVAX;

        IBenQiComptroller(comptroller).claimReward(0, holders, qiTokens, false, true);
        IBenQiComptroller(comptroller).claimReward(1, holders, qiTokens, false, true);

        if (address(this).balance != 0) IWAvax(WAVAX).deposit{ value: address(this).balance };
    }

    /*///////////////////////////////////////////////////////////////
                    MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    /*
     * @dev 'tokenIn' accepted for deposit are NATIVE, WAVAX, SAVAX and QiSAVAX.
     */
    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == QI_SAVAX) {
            amountSharesOut = amountTokenToDeposit;
        } else if (tokenIn == SAVAX) {
            amountSharesOut = (amountTokenToDeposit * 1e18) / _exchangeRateCurrentView();
        } else {
            // NATIVE or WAVAX - use exchange rate from qiSAvax to underlying asset.
            amountSharesOut = (amountTokenToDeposit * 1e18) / exchangeRate();
        }
    }

    /*
     * @dev 'tokenOut' accepted for deposit are SAVAX and QiSAVAX.
     */
    function _previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        view
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == QI_SAVAX) {
            amountTokenOut = amountSharesToRedeem;
        } else {
            // if 'tokenOut' == SAVAX
            amountTokenOut = (amountSharesToRedeem * _exchangeRateCurrentView()) / 1e18;
        }
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = QI_SAVAX;
        res[1] = SAVAX;
        res[2] = WAVAX;
        res[4] = NATIVE;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = QI_SAVAX;
        res[1] = SAVAX;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == QI_SAVAX || token == SAVAX || token == WAVAX || token == NATIVE;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == QI_SAVAX || token == SAVAX;
    }

    function assetInfo()
        external
        pure
        returns (
            AssetType assetType,
            address assetAddress,
            uint8 assetDecimals
        )
    {
        return (AssetType.TOKEN, NATIVE, 18);
    }
}
