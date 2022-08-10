// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;
import "../../base-implementations/SCYBase.sol";
import "../../../interfaces/IEulerEToken.sol";
import "../../../interfaces/IEulerMarkets.sol";

/*
Euler Finance (Money Markets) - Permissionless Lending/Borrowing Protocol for any ERC20 tokens (Built on top of Uniswap v3 oracle protocol which faciliates people to active their own markets and manage their own lending and borrowing facilities)

External Rewards (EUL distribution) are only applicable for borrowers, hence no external rewards for SCY to deal with since only only lending feature is used.
*/

contract PendleEulerSCY is SCYBase {
    address public immutable underlying;
    address public immutable eToken;

    constructor(
        string memory _name,
        string memory _symbol,
        address _eToken,
        address _eulerMarkets, // pass eulerMarkets to double check both eToken & underlying
        address _euler // need to approve spending by euler
    ) SCYBase(_name, _symbol, _eToken) {
        require(_eToken != address(0), "zero address");
        require(_eulerMarkets != address(0), "zero address");

        eToken = _eToken;

        underlying = IEulerMarkets(_eulerMarkets).eTokenToUnderlying(eToken);

        _safeApprove(underlying, _euler, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {SCYBase-_deposit}
     *
     * The underlying yield token is underlying ETokens. Tokens accepted are EToken or the underlying base token.
     *
     *If underlying ETokens are deposited directly, they are swapped to shares 1:1
     *
     * If underlying base tokens are deposited, SCY contract will deposit into the lending pool and swap shares based on amount of eTokens minted.
     *
     * The exchange rate of EToken to shares is 1:1
     */
    function _deposit(address tokenIn, uint256 amountDeposited)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == eToken) {
            amountSharesOut = amountDeposited;
        } else {
            uint256 preBalanceEToken = _selfBalance(eToken);

            // Deposit underlying tokens to convert into eTokens
            IEulerEToken(eToken).deposit(0, amountDeposited);

            // Since 'deposit' function doesn't return the amount of eTokens minted, calculate change in EToken balance to find the amount of shares out
            amountSharesOut = _selfBalance(eToken) - preBalanceEToken;
        }
    }

    /**
     * @dev See {SCYBase-_redeem}
     *
     * The shares are redeemed into the same amount of underlying eTokens.
     *
     If `tokenOut` is underlying base Token, the function also swaps back eTokens to underlying base tokens from the lending Pool based on the prevailing exchange rate.
     *
     * The exchange rate of shares to EToken is 1:1
     */
    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == eToken) {
            amountTokenOut = amountSharesToRedeem;
        } else {
            // 'tokenOut' is underlying base token
            uint256 preBalanceUnderlying = _selfBalance(underlying);

            // Swap EToken for underlying base tokens
            IEulerEToken(eToken).withdraw(
                0,
                IEulerEToken(eToken).convertBalanceToUnderlying(amountSharesToRedeem)
            );

            // Since 'withdraw' function doesn't return the amount of underlying tokens swapped from eTokens, calculate change in underlying balance to find the amount of shares out
            amountTokenOut = _selfBalance(underlying) - preBalanceUnderlying;
        }
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates and updates the exchange rate of shares to underlying base token
     * @dev It is the exchange rate of underlying EToken (since EToken to shares is 1:1) to underlying Base Token.
     */
    function exchangeRate() public view virtual override returns (uint256 currentRate) {
        return IEulerEToken(eToken).convertBalanceToUnderlying(1e18);
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
        if (tokenIn == eToken) {
            amountSharesOut = amountTokenToDeposit;
        } else {
            amountSharesOut = IEulerEToken(eToken).convertUnderlyingToBalance(
                amountTokenToDeposit
            );
        }
    }

    function _previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        view
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == eToken) {
            amountTokenOut = amountSharesToRedeem;
        } else {
            amountTokenOut = IEulerEToken(eToken).convertBalanceToUnderlying(amountSharesToRedeem);
        }
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = underlying;
        res[1] = eToken;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = underlying;
        res[1] = eToken;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == underlying || token == eToken;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == underlying || token == eToken;
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
        // All underlying asset tokens are of ERC20 standard
        return (AssetType.TOKEN, underlying, IERC20Metadata(underlying).decimals());
    }
}
