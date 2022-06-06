// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.14;

import "../../interfaces/IJoePair.sol";
import "../../interfaces/IJoeRouter02.sol";
import "../base-implementations/SCYBase.sol";
import "../../libraries/math/LogExpMath.sol";

contract PendleJoeLpSCY is SCYBase {
    using Math for uint256;

    address public immutable joeRouter;
    address public immutable joePair;
    address public immutable token0;
    address public immutable token1;

    uint256 public override exchangeRateStored;

    constructor(
        string memory _name,
        string memory _symbol,
        address _joeRouter,
        address _joePair
    ) SCYBase(_name, _symbol, _joePair) {
        require(_joeRouter != address(0), "zero address");
        joeRouter = _joeRouter;
        joePair = _joePair;
        token0 = IJoePair(joePair).token0();
        token1 = IJoePair(joePair).token1();
        _safeApprove(token0, joeRouter, type(uint256).max);
        _safeApprove(token1, joeRouter, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address tokenIn, uint256 amount)
        internal
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == joePair) {
            amountSharesOut = amount;
        } else {
            amountSharesOut = _performZapIn(tokenIn, amount);
        }
    }

    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        override
        returns (uint256 amountBaseOut)
    {
        if (tokenOut == joePair) {
            amountBaseOut = amountSharesToRedeem;
        } else {
            amountBaseOut = _performZapOut(tokenOut, amountSharesToRedeem);
        }
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRateCurrent() public override returns (uint256 currentRate) {
        (uint256 reserve0, uint256 reserve1, ) = IJoePair(joePair).getReserves();

        // K = sqrt(reserve0 * reserve1) = pow(reserve0*reserve1, 0.5)
        uint256 currentK = LogExpMath.pow(reserve0 * reserve1, uint256(LogExpMath.ONE_18 / 2));
        uint256 totalSupply = IJoePair(joePair).totalSupply();
        currentRate = currentK.divDown(totalSupply);

        emit ExchangeRateUpdated(exchangeRateStored, currentRate);

        exchangeRateStored = currentRate;
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function getBaseTokens() public view override returns (address[] memory res) {
        res = new address[](3);
        res[0] = token0;
        res[1] = token1;
        res[2] = joePair;
    }

    function isValidBaseToken(address token) public view override returns (bool res) {
        res = (token == token0 || token == token1 || token == joePair);
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
        return (AssetType.LIQUIDITY, joePair, IERC20Metadata(joePair).decimals());
    }

    /*///////////////////////////////////////////////////////////////
                    ZAPPING IN/OUT USING ZAPPER'S ALGORITHMS
    //////////////////////////////////////////////////////////////*/

    function _performZapIn(address fromToken, uint256 amount) internal returns (uint256) {
        require(fromToken == token0 || fromToken == token1, "Invalid fromToken");
        // divide intermediate into appropriate amount to add liquidity
        (uint256 token0Bought, uint256 token1Bought) = _swapIntermediate(fromToken, amount);

        return _joeAddLiquidity(token0Bought, token1Bought, true);
    }

    function _performZapOut(address toToken, uint256 lpToRemove) internal returns (uint256) {
        (uint256 token0Received, uint256 token1Received) = _joeRemoveLiquidity(lpToRemove);

        if (toToken == token0) {
            uint256 token0FromSwap = _token2Token(token1, token0, token1Received);
            return token0Received + token0FromSwap;
        } else {
            uint256 token1FromSwap = _token2Token(token0, token1, token0Received);
            return token1Received + token1FromSwap;
        }
    }

    function _swapIntermediate(address fromToken, uint256 amount)
        internal
        returns (uint256 token0Bought, uint256 token1Bought)
    {
        (uint256 res0, uint256 res1, ) = IJoePair(joePair).getReserves();
        if (fromToken == token0) {
            uint256 amountToSwap = calculateSwapInAmount(res0, amount);
            //if no reserve or a new pair is created
            if (amountToSwap <= 0) amountToSwap = amount / 2;
            token1Bought = _token2Token(fromToken, token1, amountToSwap);
            token0Bought = amount - amountToSwap;
        } else {
            uint256 amountToSwap = calculateSwapInAmount(res1, amount);
            //if no reserve or a new pair is created
            if (amountToSwap <= 0) amountToSwap = amount / 2;
            token0Bought = _token2Token(fromToken, token0, amountToSwap);
            token1Bought = amount - amountToSwap;
        }
    }

    function _joeAddLiquidity(
        uint256 token0Bought,
        uint256 token1Bought,
        bool transferResidual
    ) internal returns (uint256) {
        (uint256 amountA, uint256 amountB, uint256 LP) = IJoeRouter02(joeRouter).addLiquidity(
            token0,
            token1,
            token0Bought,
            token1Bought,
            1,
            1,
            address(this),
            type(uint256).max
        );

        if (transferResidual) {
            //Returning Residue in token0, if any.
            if (token0Bought - amountA > 0) {
                _transferOut(token0, msg.sender, token0Bought - amountA);
            }

            //Returning Residue in token1, if any
            if (token1Bought - amountB > 0) {
                _transferOut(token1, msg.sender, token1Bought - amountB);
            }
        }

        return LP;
    }

    function _joeRemoveLiquidity(uint256 lpToRemove)
        internal
        returns (uint256 token0Received, uint256 token1Received)
    {
        (token0Received, token1Received) = IJoeRouter02(joeRouter).removeLiquidity(
            token0,
            token1,
            lpToRemove,
            1,
            1,
            address(this),
            type(uint256).max
        );
    }

    function calculateSwapInAmount(uint256 reserveIn, uint256 userIn)
        internal
        pure
        returns (uint256)
    {
        return
            (_babylonianSqrt(reserveIn * ((userIn * 3988000) + (reserveIn * 3988009))) -
                (reserveIn * 1997)) / 1994;
    }

    function _babylonianSqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // else z = 0
    }

    /**
    @notice This function is used to swap ERC20 <> ERC20
    @param fromToken The token address to swap from.
    @param toToken The token address to swap to.
    @param tokens2Trade The amount of tokens to swap
    @return tokenBought The quantity of tokens bought
    */
    function _token2Token(
        address fromToken,
        address toToken,
        uint256 tokens2Trade
    ) internal returns (uint256 tokenBought) {
        if (fromToken == toToken) {
            return tokens2Trade;
        }

        require(joePair != address(0), "No Swap Available");
        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;

        tokenBought = IJoeRouter02(joeRouter).swapExactTokensForTokens(
            tokens2Trade,
            1,
            path,
            address(this),
            type(uint256).max
        )[path.length - 1];

        require(tokenBought > 0, "Error Swapping Tokens 2");
    }
}
