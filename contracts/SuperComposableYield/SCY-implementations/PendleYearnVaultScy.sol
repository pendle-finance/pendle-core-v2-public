// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../base-implementations/SCYBase.sol";
import "../../interfaces/IYearnVault.sol";

contract PendleYearnVaultSCY is SCYBase {
    address public immutable underlying;
    address public immutable yvToken;

    uint256 public override exchangeRateStored;

    constructor(
        string memory _name,
        string memory _symbol,
        address _yvToken
    ) SCYBase(_name, _symbol, _yvToken) {
        require(_yvToken != address(0), "zero address");
        yvToken = _yvToken;
        underlying = IYearnVault(yvToken).token();
        _safeApprove(underlying, yvToken, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {SCYBase-_deposit}
     *
     * The underlying yield token is yvToken. If the base token deposited is underlying asset, the function
     * first mints yvToken using those deposited. Then the corresponding amount of shares is returned.
     *
     * The exchange rate of yvToken to shares is 1:1
     */
    function _deposit(address tokenIn, uint256 amountDeposited)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == yvToken) {
            amountSharesOut = amountDeposited;
        } else {
            // tokenIn == underlying
            uint256 preBalance = _selfBalance(yvToken);
            IYearnVault(yvToken).deposit(amountDeposited);
            amountSharesOut = _selfBalance(yvToken) - preBalance; // 1 yvToken = 1 SCY
        }
    }

    /**
     * @dev See {SCYBase-_redeem}
     *
     * The shares are redeemed into the same amount of yvTokens. If `tokenOut` is the underlying asset,
     * the function also withdraws said asset for redemption, using the corresponding amount of yvToken.
     */
    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == yvToken) {
            amountTokenOut = amountSharesToRedeem;
        } else {
            // tokenOut == underlying
            IYearnVault(yvToken).withdraw(amountSharesToRedeem);
            amountTokenOut = _selfBalance(underlying);
        }
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates and updates the exchange rate of shares to underlying asset token
     * @dev It is the price per share of the yvToken
     */
    function exchangeRateCurrent() public override returns (uint256 currentRate) {
        currentRate = IYearnVault(yvToken).pricePerShare();

        emit ExchangeRateUpdated(exchangeRateStored, currentRate);

        exchangeRateStored = currentRate;
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-getBaseTokens}
     */
    function getBaseTokens() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = underlying;
        res[1] = yvToken;
    }

    /**
     * @dev See {ISuperComposableYield-isValidBaseToken}
     */
    function isValidBaseToken(address token) public view virtual override returns (bool) {
        return token == underlying || token == yvToken;
    }

    function assetInfo()
        external
        view
        returns (
            AssetType assetType,
            address assetAddress,
            uint8 assetDecimals
        )
    {
        return (AssetType.TOKEN, underlying, IERC20Metadata(underlying).decimals());
    }
}
