// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./libraries/TokenHelper.sol";
import "./libraries/math/Math.sol";
import "./libraries/Errors.sol";
import "./BulkSellerMathCore.sol";
import "../interfaces/IStandardizedYield.sol";
import "../interfaces/IPBulkSeller.sol";

contract BulkSellerSY is TokenHelper, IPBulkSeller, AccessControl, Initializable {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using BulkSellerMathCore for BulkSellerState;

    struct BulkSellerStorage {
        uint128 coreRateTokenToSy; // higher than actual amount necessary to mint SY
        uint128 coreRateSyToToken; // lower than the actual amount of token redeemable from SY
        uint128 feeRate;
        uint128 maxDiffRate;
        uint128 totalSy;
        uint128 totalToken;
    }

    bytes32 public constant MAINTAINER = keccak256("MAINTAINER");

    address public immutable token;
    address public immutable SY;
    BulkSellerStorage public _storage;

    modifier onlyMaintainer() {
        if (!(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(MAINTAINER, msg.sender)))
            revert Errors.BulkNotMaintainer();
        _;
    }

    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert Errors.BulkNotAdmin();
        _;
    }

    constructor(address _token, address _SY) {
        token = _token;
        SY = _SY;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function initialize(uint256 _initialTokenToSyRate, uint256 _initialSyToTokenRate, uint256 _maxDiffRate)
        external
        initializer
        onlyMaintainer
    {
        BulkSellerState memory state = readState();
        state.coreRateTokenToSy = _initialTokenToSyRate;
        state.coreRateSyToToken = _initialSyToTokenRate;
        state.maxDiffRate = _maxDiffRate;
        _writeState(state);
    }

    // TODO: add events
    // TODO: add reentrancy
    function swapExactTokenForSy(
        address receiver,
        uint256 netTokenIn,
        uint256 minSyOut
    ) external returns (uint256 netSyOut) {
        BulkSellerState memory state = readState();

        netSyOut = state.swapExactTokenForSy(netTokenIn);

        if (netSyOut < minSyOut) revert Errors.BulkInSufficientSyOut(netSyOut, minSyOut);

        if (receiver != address(this)) _transferOut(SY, receiver, netSyOut);

        _writeState(state);

        if (_selfBalance(token) < state.totalToken)
            revert Errors.BulkInsufficientTokenReceived(_selfBalance(token), state.totalToken);
    }

    function swapExactSyForToken(
        address receiver,
        uint256 exactSyIn,
        uint256 minTokenOut
    ) external returns (uint256 netTokenOut) {
        BulkSellerState memory state = readState();

        netTokenOut = state.swapExactSyForToken(exactSyIn);

        if (netTokenOut < minTokenOut)
            revert Errors.BulkInSufficientTokenOut(netTokenOut, minTokenOut);
        if (receiver != address(this)) _transferOut(token, receiver, netTokenOut);

        _writeState(state);

        if (_selfBalance(SY) < state.totalSy)
            revert Errors.BulkInsufficientSyReceived(_selfBalance(SY), state.totalSy);
    }

    function readState() public view returns (BulkSellerState memory state) {
        BulkSellerStorage storage s = _storage;

        state = BulkSellerState({
            coreRateTokenToSy: s.coreRateTokenToSy,
            coreRateSyToToken: s.coreRateSyToToken,
            feeRate: s.feeRate,
            maxDiffRate: s.maxDiffRate,
            totalToken: s.totalToken,
            totalSy: s.totalSy,
            token: token,
            SY: SY
        });
    }

    function _writeState(BulkSellerState memory state) internal {
        BulkSellerStorage memory tmp = BulkSellerStorage({
            coreRateTokenToSy: state.coreRateTokenToSy.Uint128(),
            coreRateSyToToken: state.coreRateSyToToken.Uint128(),
            feeRate: state.feeRate.Uint128(),
            maxDiffRate: state.maxDiffRate.Uint128(),
            totalSy: state.totalSy.Uint128(),
            totalToken: state.totalToken.Uint128()
        });

        _storage = tmp;
    }

    //////////////////////////

    function increaseReserve(uint256 netTokenIn, uint256 netSyIn) external onlyMaintainer {
        BulkSellerState memory state = readState();

        state.totalToken += netTokenIn;
        state.totalSy += netSyIn;

        _transferIn(token, msg.sender, netTokenIn);
        _transferIn(SY, msg.sender, netSyIn);

        _writeState(state);
    }

    function decreaseReserve(uint256 netTokenOut, uint256 netSyOut) external onlyAdmin {
        BulkSellerState memory state = readState();

        if (netTokenOut == type(uint256).max) netTokenOut = state.totalToken;
        if (netSyOut == type(uint256).max) netSyOut = state.totalSy;

        state.totalToken -= netTokenOut;
        state.totalSy -= netSyOut;

        _transferOut(token, msg.sender, netTokenOut);
        _transferOut(SY, msg.sender, netSyOut);

        _writeState(state);
    }

    function reBalance(uint256 targetProportion) external onlyMaintainer {
        BulkSellerState memory state = readState();

        (uint256 netTokenToDeposit, uint256 netSyToRedeem) = state.getReBalanceParams(
            targetProportion
        );

        if (netTokenToDeposit > 0) {
            uint256 netSyFromToken = _depositToken(netTokenToDeposit);
            state.reBalanceTokenToSy(netTokenToDeposit, netSyFromToken);
        } else {
            uint256 netTokenFromSy = _redeemSy(netSyToRedeem);
            state.reBalanceSyToToken(netSyToRedeem, netTokenFromSy);
        }

        _writeState(state);
    }

    function updateRate() external onlyMaintainer {
        BulkSellerState memory state = readState();

        state.updateRateSyToToken(IStandardizedYield(SY).previewRedeem);
        state.updateRateTokenToSy(IStandardizedYield(SY).previewDeposit);

        _writeState(state);
    }

    function getTokenProportion() external view returns (uint256) {
        BulkSellerState memory state = readState();
        return state.getTokenProportion();
    }

    function _depositToken(uint256 netTokenToDeposit) internal returns (uint256 netSyFromToken) {
        _safeApprove(token, SY, netTokenToDeposit);
        return IStandardizedYield(SY).deposit(address(this), token, netTokenToDeposit, 0);
    }

    function _redeemSy(uint256 netSyToRedeem) internal returns (uint256 netTokenFromSy) {
        IERC20(SY).transfer(SY, netSyToRedeem);
        return IStandardizedYield(SY).redeem(address(this), netSyToRedeem, token, 0, true);
    }

    // TODO: add setters
    // TODO: pause contract when rate is bad compared to market
    // TODO: how to update if the requires failed
    // TODO: add a max with currentRate to guarantee no loss?
}
