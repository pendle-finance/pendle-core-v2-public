// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.17;

import "./PendleCamelotV1Base.sol";
import "./PendleCamelotRewardHelper.sol";
import "../../SYBaseWithRewards.sol";

contract PendleCamelotPepSY is PendleCamelotV1Base, SYBaseWithRewards, PendleCamelotRewardHelper {
    address public constant PENDLE = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8;

    using Math for uint256;

    constructor(
        string memory _name,
        string memory _symbol,
        address _pair,
        address _factory,
        address _router,
        address _nitroPool
    )
        PendleCamelotV1Base(_pair, _factory, _router)
        SYBaseWithRewards(_name, _symbol, _pair)
        PendleCamelotRewardHelper(_nitroPool, _pair)
    {}

    /**
     * @dev See {SYBase-_deposit}
     */
    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256) {
        uint256 amountLpDeposited;
        if (tokenIn == pair) {
            amountLpDeposited = amountDeposited;
        } else {
            amountLpDeposited = _zapIn(tokenIn, amountDeposited);
        }
        return _increaseNftPoolPosition(amountLpDeposited);
    }

    /**
     * @dev See {SYBase-_redeem}
     */
    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        _removeNftPoolPosition(amountSharesToRedeem);
        if (tokenOut == pair) {
            amountTokenOut = amountSharesToRedeem;
        } else {
            amountTokenOut = _zapOut(tokenOut, amountSharesToRedeem);
        }
        _transferOut(tokenOut, receiver, amountTokenOut);
    }

    /**
     * @notice Both Pendle and ETH has 18 decimals so this exchangeRate should not cause
     * any readibility issues
     */
    function exchangeRate() public view virtual override returns (uint256) {
        (uint256 reserve0, uint256 reserve1, , ) = ICamelotPair(pair).getReserves();
        uint256 supply = ICamelotPair(pair).totalSupply();
        return sqrt(reserve0 * reserve1).divDown(supply);
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {IStandardizedYield-getRewardTokens}
     */
    function _getRewardTokens() internal view override returns (address[] memory res) {
        res = new address[](2);
        res[0] = PENDLE;
        res[1] = GRAIL;
    }

    function _redeemExternalReward() internal override {
        ICamelotNitroPool(nitroPool).harvest();
        ICamelotNFTPool(nftPool).harvestPosition(positionId);
        _allocateXGrail();
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view override returns (uint256) {
        if (tokenIn == pair) {
            return amountTokenToDeposit;
        } else {
            return _previewZapIn(tokenIn, amountTokenToDeposit);
        }
    }

    function _previewRedeem(
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal view override returns (uint256) {
        if (tokenOut == pair) {
            return amountSharesToRedeem;
        } else {
            return _previewZapOut(tokenOut, amountSharesToRedeem);
        }
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](3);
        res[0] = token0;
        res[1] = token1;
        res[2] = pair;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](3);
        res[0] = token0;
        res[1] = token1;
        res[2] = pair;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == token0 || token == token1 || token == pair;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == token0 || token == token1 || token == pair;
    }

    function assetInfo()
        external
        view
        returns (AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (AssetType.LIQUIDITY, pair, IERC20Metadata(pair).decimals());
    }
}
