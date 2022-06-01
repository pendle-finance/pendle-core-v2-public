// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./PendleBaseToken.sol";
import "../interfaces/IPPrincipalToken.sol";
import "../interfaces/ISuperComposableYield.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPMarketFactory.sol";
import "../interfaces/IPMarketSwapCallback.sol";
import "../interfaces/IPMarketAddRemoveCallback.sol";

import "../libraries/math/LogExpMath.sol";
import "../libraries/math/Math.sol";
import "../libraries/math/MarketMathAux.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// solhint-disable reason-string
contract PendleMarket is PendleBaseToken, IPMarket {
    using Math for uint256;
    using Math for int256;
    using Math for uint128;
    using LogExpMath for uint256;
    using MarketMathAux for MarketState;
    using MarketMathCore for MarketState;
    using SafeERC20 for IERC20;

    struct MarketStorage {
        int128 totalPt;
        int128 totalScy;
        // 1 SLOT = 256 bits
        uint96 lastLnImpliedRate;
        uint96 oracleRate;
        uint32 lastTradeTime;
        uint8 _reentrancyStatus;
        // 1 SLOT = 232 bits
    }

    uint8 private constant _NOT_ENTERED = 1;
    uint8 private constant _ENTERED = 2;

    string private constant NAME = "Pendle Market";
    string private constant SYMBOL = "PENDLE-LPT";

    address public immutable PT;
    address public immutable SCY;
    address public immutable YT;

    int256 public immutable scalarRoot;
    int256 public immutable initialAnchor;

    MarketStorage public _storage;

    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_storage._reentrancyStatus != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _storage._reentrancyStatus = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _storage._reentrancyStatus = _NOT_ENTERED;
    }

    constructor(
        address _PT,
        int256 _scalarRoot,
        int256 _initialAnchor
    ) PendleBaseToken(NAME, SYMBOL, 18, IPPrincipalToken(_PT).expiry()) {
        PT = _PT;
        SCY = IPPrincipalToken(_PT).SCY();
        YT = IPPrincipalToken(_PT).YT();

        require(_scalarRoot > 0, "scalarRoot must be positive");
        scalarRoot = _scalarRoot;
        initialAnchor = _initialAnchor;
        _storage._reentrancyStatus = _NOT_ENTERED;
    }

    /**
     * @notice PendleMarket allows users to provide in PT & SCY in exchange for LPs, which
     * will grant LP holders more exchange fee over time
     * @dev steps working of this function:
       - Releases the proportional amount of LP to receiver
       - Callback to msg.sender if data.length > 0
       - Ensure that the corresponding amount of SCY & PT have been transferred to this address
     * @param data bytes data to be sent in the callback
     */
    function addLiquidity(
        address receiver,
        uint256 scyDesired,
        uint256 ptDesired,
        bytes calldata data
    )
        external
        nonReentrant
        returns (
            uint256 lpToAccount,
            uint256 scyUsed,
            uint256 ptUsed
        )
    {
        MarketState memory market = readState(true);
        SCYIndex index = SCYIndexLib.newIndex(SCY);

        uint256 lpToReserve;
        (lpToReserve, lpToAccount, scyUsed, ptUsed) = market.addLiquidity(
            index,
            scyDesired,
            ptDesired,
            true
        );

        // initializing the market
        if (lpToReserve != 0) {
            market.setInitialLnImpliedRate(index, initialAnchor, block.timestamp);
            _mint(address(1), lpToReserve);
        }

        _mint(receiver, lpToAccount);

        _writeState(market);

        if (data.length > 0) {
            IPMarketAddRemoveCallback(msg.sender).addLiquidityCallback(
                receiver,
                lpToAccount,
                scyUsed,
                ptUsed,
                data
            );
        }

        require(market.totalPt.Uint() <= IERC20(PT).balanceOf(address(this)));
        require(market.totalScy.Uint() <= IERC20(SCY).balanceOf(address(this)));

        emit AddLiquidity(receiver, lpToAccount, scyUsed, ptUsed);
    }

    /**
     * @notice LP Holders can burn their LP to receive back SCY & PT proportionally
     * to their share of market
     * @dev steps working of this contract
       - SCY & PT will be first transferred out to receiver
       - Callback to msg.sender if data.length > 0
       - Ensure the corresponding amount of LP has been transferred to this contract
     * @param data bytes data to be sent in the callback
     */
    function removeLiquidity(
        address receiverScy,
        address receiverPt,
        uint256 lpToRemove,
        bytes calldata data
    ) public nonReentrant returns (uint256 scyToAccount, uint256 ptToAccount) {
        MarketState memory market = readState(true);

        (scyToAccount, ptToAccount) = market.removeLiquidity(lpToRemove, true);

        IERC20(SCY).safeTransfer(receiverScy, scyToAccount);
        IERC20(PT).safeTransfer(receiverPt, ptToAccount);

        _writeState(market);

        if (data.length > 0) {
            IPMarketAddRemoveCallback(msg.sender).removeLiquidityCallback(
                receiverScy,
                receiverPt,
                lpToRemove,
                scyToAccount,
                ptToAccount,
                data
            );
        }

        _burn(address(this), lpToRemove);

        emit RemoveLiquidity(receiverScy, receiverPt, lpToRemove, scyToAccount, ptToAccount);
    }

    /**
     * @notice Pendle Market allows swaps between PT & SCY it is holding. This function
     * aims to swap an exact amount of PT to SCY.
     * @dev steps working of this contract
       - The outcome amount of SCY will be precomputed by MarketMathLib
       - Release the calculated amount of SCY to receiver
       - Callback to msg.sender if data.length > 0
       - Ensure exactPtIn amount of PT has been transferred to this address
     * @param data bytes data to be sent in the callback
     */
    function swapExactPtForScy(
        address receiver,
        uint256 exactPtIn,
        uint256 minScyOut,
        bytes calldata data
    ) external nonReentrant returns (uint256 netScyOut, uint256 netScyToReserve) {
        require(block.timestamp < expiry, "MARKET_EXPIRED");

        MarketState memory market = readState(true);

        (netScyOut, netScyToReserve) = market.swapExactPtForScy(
            SCYIndexLib.newIndex(SCY),
            exactPtIn,
            block.timestamp,
            true
        );
        require(netScyOut >= minScyOut, "insufficient scy out");

        IERC20(SCY).safeTransfer(receiver, netScyOut);
        IERC20(SCY).safeTransfer(market.treasury, netScyToReserve);

        _writeState(market);

        if (data.length > 0) {
            IPMarketSwapCallback(msg.sender).swapCallback(exactPtIn.neg(), netScyOut.Int(), data);
        }

        // have received enough PT
        require(market.totalPt.Uint() <= IERC20(PT).balanceOf(address(this)));

        emit Swap(receiver, exactPtIn.neg(), netScyOut.Int(), netScyToReserve);
    }

    /**
     * @notice Pendle Market allows swaps between PT & SCY it is holding. This function
     * aims to swap an exact amount of SCY to PT.
     * @dev steps working of this function
       - The exact outcome amount of PT will be transferred to receiver
       - Callback to msg.sender if data.length > 0
       - Ensure the calculated required amount of SCY is transferred to this address
     * @param data bytes data to be sent in the callback
     */
    function swapScyForExactPt(
        address receiver,
        uint256 exactPtOut,
        uint256 maxScyIn,
        bytes calldata data
    ) external nonReentrant returns (uint256 netScyIn, uint256 netScyToReserve) {
        require(block.timestamp < expiry, "MARKET_EXPIRED");

        MarketState memory market = readState(true);

        (netScyIn, netScyToReserve) = market.swapScyForExactPt(
            SCYIndexLib.newIndex(SCY),
            exactPtOut,
            block.timestamp,
            true
        );
        require(netScyIn <= maxScyIn, "scy in exceed limit");

        IERC20(PT).safeTransfer(receiver, exactPtOut);
        IERC20(SCY).safeTransfer(market.treasury, netScyToReserve);

        _writeState(market);

        if (data.length > 0) {
            IPMarketSwapCallback(msg.sender).swapCallback(exactPtOut.Int(), netScyIn.neg(), data);
        }

        // have received enough SCY
        require(market.totalScy.Uint() <= IERC20(SCY).balanceOf(address(this)));

        emit Swap(receiver, exactPtOut.Int(), netScyIn.neg(), netScyToReserve);
    }

    /// @dev this function is just a place holder. Later on the rewards will be transferred to the liquidity minining
    /// instead
    function redeemScyReward() external returns (uint256[] memory outAmounts) {
        outAmounts = ISuperComposableYield(SCY).claimRewards(address(this));
        address[] memory rewardTokens = ISuperComposableYield(SCY).getRewardTokens();
        address treasury = IPMarketFactory(factory).treasury();
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20(rewardTokens[i]).safeTransfer(treasury, outAmounts[i]);
        }
    }

    function readTokens()
        external
        view
        returns (
            ISuperComposableYield _SCY,
            IPPrincipalToken _PT,
            IPYieldToken _YT
        )
    {
        _SCY = ISuperComposableYield(SCY);
        _PT = IPPrincipalToken(PT);
        _YT = IPYieldToken(YT);
    }

    function readState(bool updateRateOracle) public view returns (MarketState memory market) {
        MarketStorage memory local = _storage;

        market.totalPt = local.totalPt;
        market.totalScy = local.totalScy;
        market.totalLp = totalSupply().Int();
        market.oracleRate = local.oracleRate;

        (
            market.treasury,
            market.lnFeeRateRoot,
            market.rateOracleTimeWindow,
            market.reserveFeePercent
        ) = IPMarketFactory(factory).marketConfig();

        market.scalarRoot = scalarRoot;
        market.expiry = expiry;

        market.lastLnImpliedRate = local.lastLnImpliedRate;
        market.lastTradeTime = local.lastTradeTime;

        if (updateRateOracle) {
            // must happen after lastLnImpliedRate & lastTradeTime is filled
            market.oracleRate = market.getNewRateOracle(block.timestamp);
        }
    }

    function _writeState(MarketState memory market) internal {
        _storage.totalPt = market.totalPt.Int128();
        _storage.totalScy = market.totalScy.Int128();
        _storage.lastLnImpliedRate = market.lastLnImpliedRate.Uint96();
        _storage.oracleRate = market.oracleRate.Uint96();
        _storage.lastTradeTime = market.lastTradeTime.Uint32();
        emit UpdateImpliedRate(block.timestamp, market.lastLnImpliedRate);
    }
}
