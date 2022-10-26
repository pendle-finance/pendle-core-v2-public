// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./libraries/TokenHelper.sol";
import "./libraries/math/Math.sol";
import "./libraries/Errors.sol";
import "./BulkSellerMathCore.sol";
import "../interfaces/IStandardizedYield.sol";
import "../interfaces/IPBulkSeller.sol";

contract BulkSellerSY is
    TokenHelper,
    IPBulkSeller,
    AccessControl,
    Initializable,
    ReentrancyGuard,
    Pausable
{
    using Math for uint256;
    using SafeERC20 for IERC20;
    using BulkSellerMathCore for BulkSellerState;

    event SwapExactTokenForSy(address receiver, uint256 netTokenIn, uint256 netSyOut);
    event SwapExactSyForToken(address receiver, uint256 netSyIn, uint256 netTokenOut);
    event RateUpdated(
        uint256 newRateTokenToSy,
        uint256 newRateSyToToken,
        uint256 oldRateTokenToSy,
        uint256 oldRateSyToToken
    );
    event ReBalanceTokenToSy(
        uint256 netTokenDeposit,
        uint256 netSyFromToken,
        uint256 newTokenProp,
        uint256 oldTokenProp
    );
    event ReBalanceSyToToken(
        uint256 netSyRedeem,
        uint256 netTokenFromSy,
        uint256 newTokenProp,
        uint256 oldTokenProp
    );
    event ReserveUpdated(uint256 totalToken, uint256 totalSy);

    struct BulkSellerStorage {
        uint128 rateTokenToSy;
        uint128 rateSyToToken;
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

    function swapExactTokenForSy(
        address receiver,
        uint256 netTokenIn,
        uint256 minSyOut
    ) external nonReentrant returns (uint256 netSyOut) {
        BulkSellerState memory state = readState();

        netSyOut = state.swapExactTokenForSy(netTokenIn);

        if (netSyOut < minSyOut) revert Errors.BulkInSufficientSyOut(netSyOut, minSyOut);

        if (receiver != address(this)) _transferOut(SY, receiver, netSyOut);

        _writeState(state);

        if (_selfBalance(token) < state.totalToken)
            revert Errors.BulkInsufficientTokenReceived(_selfBalance(token), state.totalToken);

        emit SwapExactTokenForSy(receiver, netTokenIn, netSyOut);
    }

    function swapExactSyForToken(
        address receiver,
        uint256 exactSyIn,
        uint256 minTokenOut
    ) external nonReentrant returns (uint256 netTokenOut) {
        BulkSellerState memory state = readState();

        netTokenOut = state.swapExactSyForToken(exactSyIn);

        if (netTokenOut < minTokenOut)
            revert Errors.BulkInSufficientTokenOut(netTokenOut, minTokenOut);
        if (receiver != address(this)) _transferOut(token, receiver, netTokenOut);

        _writeState(state);

        if (_selfBalance(SY) < state.totalSy)
            revert Errors.BulkInsufficientSyReceived(_selfBalance(SY), state.totalSy);

        emit SwapExactSyForToken(receiver, exactSyIn, netTokenOut);
    }

    function calcSwapExactTokenForSy(uint256 netTokenIn) external view returns (uint256 netSyOut) {
        assert(_storage.rateTokenToSy != 0);
        netSyOut = netTokenIn.mulDown(_storage.rateTokenToSy);
    }

    function calcSwapExactSyForToken(uint256 netSyIn) external view returns (uint256 netTokenOut) {
        assert(_storage.rateSyToToken != 0);
        netTokenOut = netSyIn.mulDown(_storage.rateSyToToken);
    }

    function readState() public view returns (BulkSellerState memory state) {
        BulkSellerStorage storage s = _storage;

        state = BulkSellerState({
            rateTokenToSy: s.rateTokenToSy,
            rateSyToToken: s.rateSyToToken,
            totalToken: s.totalToken,
            totalSy: s.totalSy
        });
    }

    function _writeState(BulkSellerState memory state) internal {
        BulkSellerStorage memory tmp = BulkSellerStorage({
            rateTokenToSy: state.rateTokenToSy.Uint128(),
            rateSyToToken: state.rateSyToToken.Uint128(),
            totalSy: state.totalSy.Uint128(),
            totalToken: state.totalToken.Uint128()
        });

        _storage = tmp;
    }

    //////////////////////////

    function pause() external onlyMaintainer {
        _pause();
    }

    function unpause() external onlyMaintainer {
        _unpause();
    }

    function increaseReserve(uint256 netTokenIn, uint256 netSyIn) external onlyMaintainer {
        BulkSellerState memory state = readState();

        state.totalToken += netTokenIn;
        state.totalSy += netSyIn;

        _transferIn(token, msg.sender, netTokenIn);
        _transferIn(SY, msg.sender, netSyIn);

        emit ReserveUpdated(state.totalToken, state.totalSy);

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

        emit ReserveUpdated(state.totalToken, state.totalSy);

        _writeState(state);
    }

    function reBalance(uint256 targetProp, uint256 maxDiff) external onlyMaintainer {
        BulkSellerState memory state = readState();
        uint256 oldTokenProp = state.getTokenProp();

        (uint256 netTokenDeposit, uint256 netSyRedeem) = state.getReBalanceParams(targetProp);

        if (netTokenDeposit > 0) {
            uint256 netSyFromToken = _depositToken(netTokenDeposit);
            state.reBalanceTokenToSy(netTokenDeposit, netSyFromToken, maxDiff);

            uint256 newTokenProp = state.getTokenProp();
            emit ReBalanceTokenToSy(netTokenDeposit, netSyFromToken, newTokenProp, oldTokenProp);
        } else {
            uint256 netTokenFromSy = _redeemSy(netSyRedeem);
            state.reBalanceSyToToken(netSyRedeem, netTokenFromSy, maxDiff);

            uint256 newTokenProp = state.getTokenProp();
            emit ReBalanceSyToToken(netSyRedeem, netTokenFromSy, newTokenProp, oldTokenProp);
        }

        _writeState(state);
    }

    function setRate(
        uint256 newRateSyToToken,
        uint256 newRateTokenToSy,
        uint256 maxDiff
    ) external onlyMaintainer {
        BulkSellerState memory state = readState();

        emit RateUpdated(
            newRateTokenToSy,
            newRateSyToToken,
            state.rateTokenToSy,
            state.rateSyToToken
        );

        state.setRate(newRateSyToToken, newRateTokenToSy, maxDiff);

        _writeState(state);
    }

    function getTokenProp() external view returns (uint256) {
        BulkSellerState memory state = readState();
        return state.getTokenProp();
    }

    function _depositToken(uint256 netTokenDeposit) internal returns (uint256 netSyFromToken) {
        _safeApprove(token, SY, netTokenDeposit);
        return IStandardizedYield(SY).deposit(address(this), token, netTokenDeposit, 0);
    }

    function _redeemSy(uint256 netSyRedeem) internal returns (uint256 netTokenFromSy) {
        _transferOut(SY, SY, netSyRedeem);
        return IStandardizedYield(SY).redeem(address(this), netSyRedeem, token, 0, true);
    }
}
