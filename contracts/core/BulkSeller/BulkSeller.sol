// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../../interfaces/IStandardizedYield.sol";
import "../../interfaces/IPBulkSellerFactory.sol";
import "../../interfaces/IPBulkSeller.sol";

import "../libraries/TokenHelper.sol";
import "../libraries/math/Math.sol";
import "../libraries/Errors.sol";

import "./BulkSellerMathCore.sol";

contract BulkSeller is IPBulkSeller, Initializable, TokenHelper, ReentrancyGuardUpgradeable {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using BulkSellerMathCore for BulkSellerState;

    struct BulkSellerStorage {
        uint128 rateTokenToSy;
        uint128 rateSyToToken;
        uint128 totalSy;
        uint128 totalToken;
    }

    address public token;
    address public SY;
    uint64 public feeRate;

    address public factory;
    BulkSellerStorage public _storage;

    modifier onlyMaintainer() {
        if (!IPBulkSellerFactory(factory).isMaintainer(msg.sender))
            revert Errors.BulkNotMaintainer();
        _;
    }

    // Since this contract is a beacon contract, no constructor should be defined.
    function initialize(
        address _token,
        address _SY,
        address _factory
    ) external initializer {
        __ReentrancyGuard_init();
        token = _token;
        SY = _SY;
        factory = _factory;
        _safeApproveInf(token, SY);
    }

    function swapExactTokenForSy(
        address receiver,
        uint256 netTokenIn,
        uint256 minSyOut
    ) external payable nonReentrant returns (uint256 netSyOut) {
        BulkSellerState memory state = readState();

        _transferIn(token, msg.sender, netTokenIn);

        netSyOut = state.swapExactTokenForSy(netTokenIn);

        if (netSyOut < minSyOut) revert Errors.BulkInSufficientSyOut(netSyOut, minSyOut);

        _transferOut(SY, receiver, netSyOut);

        _writeState(state);

        emit SwapExactTokenForSy(receiver, netTokenIn, netSyOut);
    }

    function swapExactSyForToken(
        address receiver,
        uint256 exactSyIn,
        uint256 minTokenOut,
        bool swapFromInternalBalance
    ) external nonReentrant returns (uint256 netTokenOut) {
        BulkSellerState memory state = readState();

        if (!swapFromInternalBalance) _transferIn(SY, msg.sender, exactSyIn);
        else {
            uint256 netSyReceived = _selfBalance(SY) - state.totalSy;
            if (netSyReceived < exactSyIn)
                revert Errors.BulkInsufficientSyReceived(exactSyIn, netSyReceived);
        }

        netTokenOut = state.swapExactSyForToken(exactSyIn);

        if (netTokenOut < minTokenOut)
            revert Errors.BulkInSufficientTokenOut(netTokenOut, minTokenOut);

        _transferOut(token, receiver, netTokenOut);

        _writeState(state);

        emit SwapExactSyForToken(receiver, exactSyIn, netTokenOut);
    }

    function readState() public view returns (BulkSellerState memory state) {
        BulkSellerStorage storage s = _storage;

        state = BulkSellerState({
            rateTokenToSy: s.rateTokenToSy,
            rateSyToToken: s.rateSyToToken,
            totalToken: s.totalToken,
            totalSy: s.totalSy,
            feeRate: feeRate
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

    // ----------------- BulkSeller management -----------------

    function increaseReserve(uint256 netTokenIn, uint256 netSyIn) external payable onlyMaintainer {
        BulkSellerState memory state = readState();

        state.totalToken += netTokenIn;
        state.totalSy += netSyIn;

        _transferIn(token, msg.sender, netTokenIn);
        _transferIn(SY, msg.sender, netSyIn);

        emit ReserveUpdated(state.totalToken, state.totalSy);

        _writeState(state);
    }

    function decreaseReserve(uint256 netTokenOut, uint256 netSyOut) external onlyMaintainer {
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

    function redeemRewards() external onlyMaintainer {
        IStandardizedYield(SY).claimRewards(address(this));
        address[] memory rewardTokens = IStandardizedYield(SY).getRewardTokens();

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (rewardTokens[i] == token) continue;
            _transferOut(rewardTokens[i], msg.sender, _selfBalance(rewardTokens[i]));
        }
    }

    function skim() external onlyMaintainer {
        BulkSellerState memory state = readState();
        uint256 excessToken = _selfBalance(token) - state.totalToken;
        uint256 excessSy = _selfBalance(SY) - state.totalSy;
        if (excessToken != 0) IERC20(token).safeTransfer(msg.sender, excessToken);
        if (excessSy != 0) IERC20(SY).safeTransfer(msg.sender, excessSy);
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

    function setFeeRate(uint64 newFeeRate) external onlyMaintainer {
        emit FeeRateUpdated(newFeeRate, feeRate);
        feeRate = newFeeRate;
    }

    function _depositToken(uint256 netTokenDeposit) internal returns (uint256 netSyFromToken) {
        uint256 nativeToDeposit = token == NATIVE ? netTokenDeposit : 0;
        return
            IStandardizedYield(SY).deposit{ value: nativeToDeposit }(
                address(this),
                token,
                netTokenDeposit,
                0
            );
    }

    function _redeemSy(uint256 netSyRedeem) internal returns (uint256 netTokenFromSy) {
        _transferOut(SY, SY, netSyRedeem);
        return IStandardizedYield(SY).redeem(address(this), netSyRedeem, token, 0, true);
    }
}
