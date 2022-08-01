// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../base-implementations/SCYBase.sol";
import "../../../interfaces/ISAvax.sol";
import "../../../interfaces/IWAvax.sol";

// BENQI Stake AVAX (sAVAX) -> 0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE

// Exchange rate of sAVAX -> AVAX increases over time, no additional rewards but has a 15day lock-up period with 2 day redemption period.
// Yield Token -> sAVAX (Interest Bearing)

contract PendleSAvaxSCY is SCYBase {
    address public immutable SAVAX;
    address public immutable WAVAX;

    uint256 private constant BASE = 1e18;

    constructor(
        string memory _name,
        string memory _symbol,
        address _sAvax,
        address _wAvax
    ) SCYBase(_name, _symbol, _sAvax) {
        require(_sAvax != address(0), "zero address");
        require(_wAvax != address(0), "zero address");
        SAVAX = _sAvax;
        WAVAX = _wAvax;
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {SCYBase-_deposit}
     *
     * The underlying yield token is sAvax. Tokens accepted for deposit are NATIVE, WVAX, and sAVAX.
     *
     *If the base token deposited is native AVAX, the function converts it into sAVAX first. Then the corresponding amount of shares is returned.
     *
     * If WAVAX is deposited, it will first unwrap to native AVAX and then convert into sAVAX.
     *
     * The exchange rate of sAVAX to shares is 1:1
     */
    function _deposit(address tokenIn, uint256 amountDeposited)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        // Comments: No check for address token IN (need to be implemented in higher level function)
        if (tokenIn == SAVAX) {
            amountSharesOut = amountDeposited;
        } else {
            // Handle WAVAX or NATIVE Avax - If WAVAX need to unwrap to NATIVE Avax first then deposit.
            if (tokenIn == WAVAX) {
                IWAvax(WAVAX).withdraw(amountDeposited);
            }

            amountSharesOut = ISAvax(tokenIn).submit{ value: amountDeposited }();
        }
    }

    /**
     * @dev See {SCYBase-_redeem}
     *
     * The shares are redeemed into the same amount of sAVAX. `tokenOut` will only be in sAVAX where exchange rate will be 1:1 to SCY.
     */
    function _redeem(address, uint256 amountSharesToRedeem)
        internal
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        amountTokenOut = amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates and updates the exchange rate of shares to underlying asset token
     * @dev It is the exchange rate of sAVAX to AVAX.
     */
    function exchangeRate() public view virtual override returns (uint256 currentRate) {
        return ISAvax(SAVAX).getPooledAvaxByShares(BASE);
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
        if (tokenIn == SAVAX) amountSharesOut = amountTokenToDeposit;
        else amountSharesOut = (amountTokenToDeposit * 1e18) / exchangeRate();
    }

    function _previewRedeem(address, uint256 amountSharesToRedeem)
        internal
        view
        override
        returns (uint256 amountTokenOut)
    {
        // Since only SAvax can be redeemed
        amountTokenOut = amountSharesToRedeem;
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](3);
        res[0] = NATIVE;
        res[1] = SAVAX;
        res[2] = WAVAX;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](1);
        res[0] = SAVAX;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return (token == NATIVE || token == SAVAX || token == WAVAX);
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == SAVAX;
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
