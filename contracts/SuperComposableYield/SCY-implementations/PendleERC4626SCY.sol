// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;
import "../base-implementations/SCYBase.sol";
import "../../interfaces/IERC4626.sol";
import "../../libraries/math/Math.sol";

contract PendleERC4626SCY is SCYBase {
    using Math for uint256;
    // if exchangeRate is >= 3e38, the contract will overflow & frozen.
    // Therefore, a reasonable limit (1e30) is set here. It can be removed
    // if the implementer is fully aware of the risk
    uint256 private constant MAX_EXCHANGE_RATE = 1e30;

    address public immutable underlying;

    constructor(
        string memory _name,
        string memory _symbol,
        IERC4626 _yieldToken
    ) SCYBase(_name, _symbol, address(_yieldToken)) {
        underlying = _yieldToken.asset();
        _safeApprove(underlying, yieldToken, type(uint256).max);
        _validateERC4626SCY();
    }

    function _validateERC4626SCY() internal view {
        require(exchangeRate() <= 1e30, "too big exchangeRate");
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address tokenIn, uint256 amountDeposited)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        // 1 4626 = 1 Share
        if (tokenIn == yieldToken) {
            amountSharesOut = amountDeposited;
        } else {
            // must be underlying
            amountSharesOut = IERC4626(yieldToken).deposit(amountDeposited, address(this));
        }
    }

    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == yieldToken) {
            amountTokenOut = amountSharesToRedeem;
        } else {
            amountTokenOut = IERC4626(yieldToken).redeem(
                amountSharesToRedeem,
                address(this),
                address(this)
            );
        }
    }

    /*///////////////////////////////////////////////////////////////
                               SCY-INDEX
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return IERC4626(yieldToken).convertToAssets(Math.ONE);
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
        if (tokenIn == yieldToken) amountSharesOut = amountTokenToDeposit;
        else amountSharesOut = (amountTokenToDeposit * 1e18) / exchangeRate();
    }

    function _previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        view
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == yieldToken) amountTokenOut = amountSharesToRedeem;
        else amountTokenOut = (amountSharesToRedeem * exchangeRate()) / 1e18;
    }

    function getBaseTokens() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = underlying;
        res[1] = yieldToken;
    }

    function isValidBaseToken(address token) public view virtual override returns (bool) {
        return token == underlying || token == yieldToken;
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
