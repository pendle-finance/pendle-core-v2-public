// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../base-implementations/SCYBase.sol";
import "../../interfaces/IWXBTRFLY.sol";
import "../../interfaces/IREDACTEDStaking.sol";

contract PendleBtrflyScy is SCYBase {
    address public immutable BTRFLY;
    address public immutable xBTRFLY;
    address public immutable wxBTRFLY;

    uint256 public override exchangeRateStored;

    constructor(
        string memory _name,
        string memory _symbol,
        address _wxBTRFLY
    ) SCYBase(_name, _symbol, _wxBTRFLY) {
        require(_wxBTRFLY != address(0), "zero address");
        wxBTRFLY = _wxBTRFLY;
        BTRFLY = IWXBTRFLY(wxBTRFLY).BTRFLY();
        xBTRFLY = IWXBTRFLY(wxBTRFLY).xBTRFLY();

        _safeApprove(BTRFLY, wxBTRFLY, type(uint256).max);
        _safeApprove(xBTRFLY, wxBTRFLY, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {SCYBase-_deposit}
     *
     * The underlying yield token is wxBTRFLY. If the base token is not said token, the contract
     * first wraps from `tokenIn` to wxBRTRFLY. Then the corresponding amount of shares is returned.
     *
     * The exchange rate of wxBTRFLY to shares is 1:1
     */
    function _deposit(address tokenIn, uint256 amountDeposited)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == wxBTRFLY) {
            amountSharesOut = amountDeposited;
        } else if (tokenIn == xBTRFLY) {
            // wrapFromxBTRFLY returns amountWXBTRFLYout
            amountSharesOut = IWXBTRFLY(wxBTRFLY).wrapFromxBTRFLY(amountDeposited);
        } else {
            // must be BTRFLY
            // wrapFromBTRFLY returns amountWXBTRFLYout
            amountSharesOut = IWXBTRFLY(wxBTRFLY).wrapFromBTRFLY(amountDeposited);
        }
    }

    /**
     * @dev See {SCYBase-_redeem}
     *
     * The shares are redeemed into the same amount of wxBTRFLY. If `tokenOut` is not wxBTRFLY
     * the function unwraps said amount of wxBTRFLY into `tokenOut` for redemption.
     */
    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == wxBTRFLY) {
            amountTokenOut = amountSharesToRedeem;
        } else if (tokenOut == xBTRFLY) {
            amountTokenOut = IWXBTRFLY(wxBTRFLY).unwrapToxBTRFLY(amountSharesToRedeem);
        } else {
            // must be BTRFLY
            amountTokenOut = IWXBTRFLY(wxBTRFLY).unwrapToBTRFLY(amountSharesToRedeem);
        }
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates and updates the exchange rate of shares to underlying asset token
     * @dev It is the conversion rate of wxBTRFLY to BTRFLY
     */
    function exchangeRateCurrent() public virtual override returns (uint256 currentRate) {
        currentRate = IWXBTRFLY(wxBTRFLY).xBTRFLYValue(Math.ONE);

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
        res = new address[](3);
        res[0] = BTRFLY;
        res[1] = xBTRFLY;
        res[2] = wxBTRFLY;
    }

    /**
     * @dev See {ISuperComposableYield-isValidBaseToken}
     */
    function isValidBaseToken(address token) public view virtual override returns (bool) {
        return token == BTRFLY || token == xBTRFLY || token == wxBTRFLY;
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
        return (AssetType.TOKEN, BTRFLY, IERC20Metadata(BTRFLY).decimals());
    }
}
