// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../PendleERC20.sol";
import "../../interfaces/IPPrincipalToken.sol";
import "../../interfaces/ISuperComposableYield.sol";
import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarketSwapCallback.sol";

import "../../libraries/math/LogExpMath.sol";
import "../../libraries/math/Math.sol";
import "../../libraries/helpers/MiniHelpers.sol";

import "../LiquidityMining/PendleGauge.sol";
import "../PendleERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
Invariances to maintain:
- Internal balances totalPt & totalScy not interferred by people transferring tokens in directly
- address(0) & address(this) should never have any rewards & activeBalance accounting done. This is
    guaranteed by address(0) & address(this) check in each updateForTwo function
*/
contract PendleMarket is PendleERC20Permit, PendleGauge, IPMarket {
    using Math for uint256;
    using Math for int256;
    using MarketMathCore for MarketState;
    using SafeERC20 for IERC20;
    using SCYIndexLib for ISuperComposableYield;

    struct MarketStorage {
        int128 totalPt;
        int128 totalScy;
        // 1 SLOT = 256 bits
        uint96 lastLnImpliedRate;
        uint96 oracleRate;
        uint32 lastTradeTime;
        // 1 SLOT = 224 bits
    }

    string private constant NAME = "Pendle Market";
    string private constant SYMBOL = "PENDLE-LPT";

    IPPrincipalToken internal immutable PT;
    ISuperComposableYield internal immutable SCY;
    IPYieldToken internal immutable YT;

    address public immutable factory;
    uint256 public immutable expiry;
    int256 public immutable scalarRoot;
    int256 public immutable initialAnchor;

    MarketStorage public _storage;

    modifier notExpired() {
        require(!isExpired(), "market expired");
        _;
    }

    constructor(
        address _PT,
        int256 _scalarRoot,
        int256 _initialAnchor,
        address _vePendle,
        address _gaugeController
    )
        PendleERC20Permit(NAME, SYMBOL, 18)
        PendleGauge(IPPrincipalToken(_PT).SCY(), _vePendle, _gaugeController)
    {
        PT = IPPrincipalToken(_PT);
        SCY = ISuperComposableYield(PT.SCY());
        YT = IPYieldToken(PT.YT());

        require(_scalarRoot > 0, "scalarRoot must be positive");
        scalarRoot = _scalarRoot;
        initialAnchor = _initialAnchor;
        expiry = IPPrincipalToken(_PT).expiry();
        factory = msg.sender;
    }

    /**
     * @notice PendleMarket allows users to provide in PT & SCY in exchange for LPs, which
     * will grant LP holders more exchange fee over time
     */
    function mint(address receiver)
        external
        nonReentrant
        notExpired
        returns (uint256 lpToAccount)
    {
        MarketState memory market = readState(true);
        SCYIndex index = SCY.newIndex();

        uint256 scyDesired = IERC20(SCY).balanceOf(address(this)) - market.totalScy.Uint();
        uint256 ptDesired = IERC20(PT).balanceOf(address(this)) - market.totalPt.Uint();

        uint256 lpToReserve;
        uint256 scyUsed;
        uint256 ptUsed;

        (lpToReserve, lpToAccount, scyUsed, ptUsed) = market.addLiquidity(
            index,
            scyDesired,
            ptDesired,
            block.timestamp
        );

        // initializing the market
        if (lpToReserve != 0) {
            market.setInitialLnImpliedRate(index, initialAnchor, block.timestamp);
            _mint(address(1), lpToReserve);
        }

        _mint(receiver, lpToAccount);

        _writeState(market);

        emit Mint(receiver, lpToAccount, scyUsed, ptUsed);
    }

    /**
     * @notice LP Holders can burn their LP to receive back SCY & PT proportionally
     * to their share of market
     */
    function burn(address receiverScy, address receiverPt)
        external
        nonReentrant
        returns (uint256 scyToAccount, uint256 ptToAccount)
    {
        MarketState memory market = readState(true);

        uint256 lpToRemove = balanceOf(address(this));
        _burn(address(this), lpToRemove);

        (scyToAccount, ptToAccount) = market.removeLiquidity(lpToRemove);

        IERC20(SCY).safeTransfer(receiverScy, scyToAccount);
        IERC20(PT).safeTransfer(receiverPt, ptToAccount);

        _writeState(market);

        emit Burn(receiverScy, receiverPt, lpToRemove, scyToAccount, ptToAccount);
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
        bytes calldata data
    ) external nonReentrant notExpired returns (uint256 netScyOut, uint256 netScyToReserve) {
        MarketState memory market = readState(true);

        (netScyOut, netScyToReserve) = market.swapExactPtForScy(
            SCY.newIndex(),
            exactPtIn,
            block.timestamp
        );

        IERC20(SCY).safeTransfer(receiver, netScyOut);
        IERC20(SCY).safeTransfer(market.treasury, netScyToReserve);

        _writeState(market);

        if (data.length > 0) {
            IPMarketSwapCallback(msg.sender).swapCallback(exactPtIn.neg(), netScyOut.Int(), data);
        }

        // have received enough PT
        require(market.totalPt.Uint() <= IERC20(PT).balanceOf(address(this)), "insufficient PT");

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
        bytes calldata data
    ) external nonReentrant notExpired returns (uint256 netScyIn, uint256 netScyToReserve) {
        MarketState memory market = readState(true);

        (netScyIn, netScyToReserve) = market.swapScyForExactPt(
            SCY.newIndex(),
            exactPtOut,
            block.timestamp
        );

        IERC20(PT).safeTransfer(receiver, exactPtOut);
        IERC20(SCY).safeTransfer(market.treasury, netScyToReserve);

        _writeState(market);

        if (data.length > 0) {
            IPMarketSwapCallback(msg.sender).swapCallback(exactPtOut.Int(), netScyIn.neg(), data);
        }

        // have received enough SCY
        require(
            market.totalScy.Uint() <= IERC20(SCY).balanceOf(address(this)),
            "insufficient SCY"
        );

        emit Swap(receiver, exactPtOut.Int(), netScyIn.neg(), netScyToReserve);
    }

    /// @notice force balances to match reserves
    function skim() external nonReentrant {
        MarketState memory market = readState(true);
        uint256 excessPt = IERC20(PT).balanceOf(address(this)) - market.totalPt.Uint();
        uint256 excessScy = IERC20(SCY).balanceOf(address(this)) - market.totalScy.Uint();
        IERC20(PT).safeTransfer(market.treasury, excessPt);
        IERC20(SCY).safeTransfer(market.treasury, excessScy);
    }

    function redeemRewards(address user) external nonReentrant returns (uint256[] memory) {
        return _redeemRewards(user);
    }

    function getRewardTokens() external view returns (address[] memory) {
        return _getRewardTokens();
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
        _SCY = SCY;
        _PT = PT;
        _YT = YT;
    }

    function isExpired() public view returns (bool) {
        return MiniHelpers.isCurrentlyExpired(expiry);
    }

    /**
     * @notice read the state of the market from storage into memory for gas-efficient manipulation
     * @param updateRateOracle if set to true, the oracleRate will be updated, which will take ~6k of gas. If router wants
        to do external calculations, normally this can be set to false
     */
    function readState(bool updateRateOracle) public view returns (MarketState memory market) {
        market.totalPt = _storage.totalPt;
        market.totalScy = _storage.totalScy;
        market.totalLp = totalSupply().Int();
        market.oracleRate = _storage.oracleRate;

        (
            market.treasury,
            market.lnFeeRateRoot,
            market.rateOracleTimeWindow,
            market.reserveFeePercent
        ) = IPMarketFactory(factory).marketConfig();

        market.scalarRoot = scalarRoot;
        market.expiry = expiry;

        market.lastLnImpliedRate = _storage.lastLnImpliedRate;
        market.lastTradeTime = _storage.lastTradeTime;

        if (updateRateOracle) {
            // must happen after lastLnImpliedRate & lastTradeTime is filled
            market.oracleRate = market.getNewRateOracle(block.timestamp);
        }
    }

    /// @notice write back the state of the market from memory to storage
    function _writeState(MarketState memory market) internal {
        _storage.totalPt = market.totalPt.Int128();
        _storage.totalScy = market.totalScy.Int128();
        _storage.lastLnImpliedRate = market.lastLnImpliedRate.Uint96();
        _storage.oracleRate = market.oracleRate.Uint96();
        _storage.lastTradeTime = market.lastTradeTime.Uint32();
        emit UpdateImpliedRate(block.timestamp, market.lastLnImpliedRate);
    }

    /*///////////////////////////////////////////////////////////////
                    PENDLE GAUGE - RELATED
    //////////////////////////////////////////////////////////////*/

    function _stakedBalance(address user) internal view override returns (uint256) {
        return balanceOf(user);
    }

    function _totalStaked() internal view override returns (uint256) {
        return totalSupply();
    }

    // solhint-disable-next-line ordering
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(PendleERC20, PendleGauge) {
        PendleGauge._beforeTokenTransfer(from, to, amount);
    }

    // solhint-disable-next-line ordering
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(PendleERC20, PendleGauge) {
        PendleGauge._afterTokenTransfer(from, to, amount);
    }
}
