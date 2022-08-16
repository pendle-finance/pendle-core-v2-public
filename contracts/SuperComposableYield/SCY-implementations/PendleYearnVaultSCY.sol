// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../base-implementations/SCYBase.sol";
import "../../interfaces/IYearnVault.sol";

contract PendleYearnVaultSCY is SCYBase {
    address public immutable underlying;
    address public immutable yvToken;
    uint256 internal immutable yvTokenDecimals;

    constructor(
        string memory _name,
        string memory _symbol,
        address _yvToken
    ) SCYBase(_name, _symbol, _yvToken) {
        require(_yvToken != address(0), "zero address");
        yvToken = _yvToken;
        underlying = IYearnVault(yvToken).token();
        yvTokenDecimals = IYearnVault(yvToken).decimals();
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
            uint256 preBalanceYvToken = _selfBalance(yvToken);

            amountTokenOut = IYearnVault(yvToken).withdraw(
                amountSharesToRedeem,
                address(this),
                10000
            );

            require(
                preBalanceYvToken - _selfBalance(yvToken) == amountSharesToRedeem,
                "Yearn Vault SCY: Not allowed to redeem all shares"
            );
        }
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates and updates the exchange rate of shares to underlying asset token
     * @dev It is the price per share of the yvToken
     */
    function exchangeRate() public view override returns (uint256) {
        uint256 price = IYearnVault(yvToken).pricePerShare();
        if (yvTokenDecimals <= 18) {
            return price * (10**(18 - yvTokenDecimals));
        } else {
            return price / (10**(yvTokenDecimals - 18));
        }
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == yvToken) amountSharesOut = amountTokenToDeposit;
        else amountSharesOut = (amountTokenToDeposit * 1e18) / exchangeRate();
    }

    function _previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        view
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == yvToken) amountTokenOut = amountSharesToRedeem;
        else amountTokenOut = (amountSharesToRedeem * exchangeRate()) / 1e18;
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = underlying;
        res[1] = yvToken;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = underlying;
        res[1] = yvToken;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == underlying || token == yvToken;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
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
