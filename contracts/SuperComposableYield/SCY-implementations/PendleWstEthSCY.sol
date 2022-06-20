// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "../base-implementations/SCYBase.sol";
import "../../interfaces/IWstETH.sol";

contract PendleWstEthSCY is SCYBase {
    address public immutable stETH;
    address public immutable wstETH;

    uint256 public override exchangeRateStored;

    constructor(
        string memory _name,
        string memory _symbol,
        address _wstETH
    ) SCYBase(_name, _symbol, _wstETH) {
        wstETH = _wstETH;
        stETH = IWstETH(wstETH).stETH();
        _safeApprove(stETH, wstETH, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {SCYBase-_deposit}
     *
     * The underlying yield token is wstETH. If the base token deposited is stETH, the function wraps
     * it into wstETH first. Then the corresponding amount of shares is returned.
     *
     * The exchange rate of wstETH to shares is 1:1
     */
    function _deposit(address tokenIn, uint256 amountDeposited)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == wstETH) {
            amountSharesOut = amountDeposited;
        } else {
            amountSharesOut = IWstETH(wstETH).wrap(amountDeposited); // .wrap returns amount of wstETH out
        }
    }

    /**
     * @dev See {SCYBase-_redeem}
     *
     * The shares are redeemed into the same amount of wstETH. If `tokenOut` is stETH, the function also
     * unwraps said amount of wstETH into stETH for redemption.
     */
    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == wstETH) {
            amountTokenOut = amountSharesToRedeem;
        } else {
            amountTokenOut = IWstETH(wstETH).unwrap(amountSharesToRedeem);
        }
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates and updates the exchange rate of shares to underlying asset token
     * @dev It is the exchange rate of wstETH to stETH
     */
    function exchangeRateCurrent() public virtual override returns (uint256 currentRate) {
        currentRate = IWstETH(wstETH).stEthPerToken();

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
        res[0] = stETH;
        res[1] = wstETH;
    }

    /**
     * @dev See {ISuperComposableYield-isValidBaseToken}
     */
    function isValidBaseToken(address token) public view virtual override returns (bool) {
        return token == stETH || token == wstETH;
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
        return (AssetType.TOKEN, stETH, IERC20Metadata(stETH).decimals());
    }
}
