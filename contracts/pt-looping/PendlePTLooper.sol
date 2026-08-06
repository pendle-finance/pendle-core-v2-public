// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {PMath} from "../core/libraries/math/PMath.sol";
import {MarketCtx, createMarketCtx} from "../interfaces/IMoneyMarket.sol";
import {ApprovedCall, BoxData, IPLoopPositionBox} from "../interfaces/IPLoopPositionBox.sol";
import {PTLooperBase} from "./PTLooperBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPPrincipalToken} from "../interfaces/IPPrincipalToken.sol";
import {IPPostPtLoopStateChecker} from "../interfaces/IPPostPtLoopStateChecker.sol";

contract PendlePTLooper is PTLooperBase {
    using PMath for uint256;

    IPPostPtLoopStateChecker public immutable POST_LOOP_STATE_CHECKER;

    constructor(address treasury, address positionBoxFactory, address postStateChecker)
        PTLooperBase(treasury, positionBoxFactory)
    {
        _disableInitializers();
        POST_LOOP_STATE_CHECKER = IPPostPtLoopStateChecker(postStateChecker);
    }

    function initialize(address _owner) external initializer {
        __EIP712_init("Pendle PT Looper", "1");
        __BoringOwnableV2_init(_owner);
    }

    /// @dev `requestHash` must match the currently-open session — caller proves *which* session
    /// is being closed, not blindly clearing the slot.
    function terminateSession(address owner, bytes32 boxId, bytes32 requestHash)
        external
        onlyExecutorOrBoxOwner(owner)
    {
        UserRequestInfo storage userReq = _userRequest[owner][boxId];
        require(userReq.requestHash != bytes32(0), "PTLooper: no open session");
        require(userReq.requestHash == requestHash, "PTLooper: requestHash mismatch");

        uint32 newSessionNonce = ++userReq.sessionNonce;
        delete userReq.requestHash;

        emit SessionTerminated(owner, boxId, requestHash, newSessionNonce);
    }

    function increaseLoopPosition(
        IncreasePositionMessage memory ms,
        bytes memory proposerSig,
        IncreasePositionRequest memory req,
        bytes memory ownerSigIfFirstCall
    ) external payable onlyExecutor {
        (Session memory s, bytes32 requestHash) = _ensureSessionAndAuth(ms, req, proposerSig, ownerSigIfFirstCall);

        uint256 preInBalance;
        uint256 netPtToMM;
        uint256 postDebtBal;

        if (_onHub(s.bd)) {
            (preInBalance, netPtToMM) = _runHubIncrease(ms, req, s);
        } else {
            netPtToMM = _boxBal(s.box, s.bd.spokePt);
        }

        if (_onSpoke(s.bd)) {
            postDebtBal = _runSpokeIncrease(ms, req, s, netPtToMM);
        }

        POST_LOOP_STATE_CHECKER.check(s.box, ms.postStateCheckData);

        emit PositionIncreased(
            ms.permit.owner, ms.permit.boxId, requestHash, ms.permit.nonce, preInBalance, netPtToMM, postDebtBal
        );
    }

    function _runHubIncrease(IncreasePositionMessage memory ms, IncreasePositionRequest memory req, Session memory s)
        internal
        returns (uint256 preInBalance, uint256 netPtToMM)
    {
        (address tokenIn, uint256 minSwapRate) = ms.permit.nonce == 0
            ? (req.initTokenIn, req.initMinToPtSwapRate)
            : (s.bd.hubDebtToken, req.minDebtToPtSwapRate);

        preInBalance = _boxBal(s.box, tokenIn);

        _boxWithdraw(s.box, TREASURY, tokenIn, ms.fee);

        uint256 netIn = preInBalance - ms.fee;

        uint256 netPtSwappedOut;
        (netPtToMM, netPtSwappedOut) = _boxSwapToken(s.box, tokenIn, netIn, s.bd.hubPt, minSwapRate, ms.swap);
        if (req.isZeroPriceImpact) {
            _boxWithdraw(s.box, ms.permit.owner, IPPrincipalToken(s.bd.hubPt).YT(), netPtSwappedOut);
        }

        if (_isCrossChain(s.bd)) {
            _boxBridgeToken(s, ms.bridge, s.bd.hubPt, netPtToMM, s.bd.spokePt, req.header.swapBridgeSlippage, false);
        }
    }

    function _runSpokeIncrease(
        IncreasePositionMessage memory ms,
        IncreasePositionRequest memory req,
        Session memory s,
        uint256 netPtToMM
    ) internal returns (uint256 postDebtBal) {
        _lendBorrowWithLTV(req, s, netPtToMM, ms.amountDebtBorrowed);

        postDebtBal = _boxBal(s.box, s.bd.spokeDebtToken);
        if (_isCrossChain(s.bd)) {
            _boxBridgeToken(
                s, ms.bridge, s.bd.spokeDebtToken, postDebtBal, s.bd.hubDebtToken, req.header.swapBridgeSlippage, false
            );
        }
    }

    function decreaseLoopPosition(
        DecreasePositionMessage memory ms,
        bytes memory proposerSig,
        DecreasePositionRequest memory req,
        bytes memory ownerSigIfFirstCall
    ) external payable onlyExecutor {
        (Session memory s, bytes32 requestHash) = _ensureSessionAndAuth(ms, req, proposerSig, ownerSigIfFirstCall);

        uint256 preDebtBal;
        uint256 netPtToSwap;
        uint256 postDebtBal;

        if (_onSpoke(s.bd)) {
            (preDebtBal, netPtToSwap) = _runSpokeDecrease(ms, req, s);
        } else {
            netPtToSwap = _boxBal(s.box, s.bd.hubPt);
        }

        if (_onHub(s.bd)) {
            postDebtBal = _runHubDecrease(ms, req, s, netPtToSwap);
        }

        POST_LOOP_STATE_CHECKER.check(s.box, ms.postStateCheckData);

        emit PositionDecreased(
            ms.permit.owner, ms.permit.boxId, requestHash, ms.permit.nonce, preDebtBal, netPtToSwap, postDebtBal
        );
    }

    function _runSpokeDecrease(DecreasePositionMessage memory ms, DecreasePositionRequest memory req, Session memory s)
        internal
        returns (uint256 preDebtBal, uint256 netPtToSwap)
    {
        preDebtBal = _boxBal(s.box, s.bd.spokeDebtToken);
        _repayWithdrawWithLTV(req, s, preDebtBal, ms.amountPtWithdrawn);

        netPtToSwap = _boxBal(s.box, s.bd.spokePt);
        if (_isCrossChain(s.bd)) {
            _boxBridgeToken(s, ms.bridge, s.bd.spokePt, netPtToSwap, s.bd.hubPt, req.header.swapBridgeSlippage, false);
        }
    }

    function _runHubDecrease(
        DecreasePositionMessage memory ms,
        DecreasePositionRequest memory req,
        Session memory s,
        uint256 netPtToSwap
    ) internal returns (uint256 postDebtBal) {
        (uint256 preFeeDebtBal,) = _boxSwapToken(
            s.box, s.bd.hubPt, netPtToSwap, s.bd.hubDebtToken, req.minPtToDebtSwapRate, ms.swap
        );

        _boxWithdraw(s.box, TREASURY, s.bd.hubDebtToken, ms.fee);
        postDebtBal = preFeeDebtBal - ms.fee;

        if (_isCrossChain(s.bd)) {
            _boxBridgeToken(
                s, ms.bridge, s.bd.hubDebtToken, postDebtBal, s.bd.spokeDebtToken, req.header.swapBridgeSlippage, false
            );
        }
    }

    function swapBridgeWithdrawAll(
        SwapBridgeWithdrawAllMessage memory ms,
        bytes memory proposerSig,
        SwapBridgeWithdrawAllRequest memory req,
        bytes memory ownerSigIfFirstCall
    ) external payable onlyExecutor {
        (Session memory s, bytes32 requestHash) = _ensureSessionAndAuth(ms, req, proposerSig, ownerSigIfFirstCall);

        address tokenOutHere = _onHub(s.bd) ? req.hubTokenOut : req.dstTokenOut;

        uint256 postBal;
        {
            address tokenIn = _debtTokenHere(s.bd);
            (postBal,) = _boxSwapToken(s.box, tokenIn, _boxBal(s.box, tokenIn), tokenOutHere, 0, ms.swap);
        }
        require(postBal >= req.minTokenWithdrawn, "PTLooper: insufficient token out");

        uint32 destChainId = req.receiveOnSpoke ? s.bd.spokeChainId : s.bd.hubChainId;
        if (destChainId != block.chainid) {
            _boxBridgeToken(s, ms.bridge, tokenOutHere, postBal, req.dstTokenOut, req.header.swapBridgeSlippage, false);
        } else {
            _boxWithdraw(s.box, ms.permit.owner, tokenOutHere, postBal);
            emit Withdrawn(ms.permit.owner, ms.permit.boxId, requestHash, ms.permit.nonce, tokenOutHere, postBal);
        }

        POST_LOOP_STATE_CHECKER.check(s.box, ms.postStateCheckData);
    }

    /// @param tokenInBal the box's `tokenIn` whole balance (`_boxBal(box, tokenIn)`) right **before** this function is called.
    /// @return postTokenOutBal the box's `tokenOut` whole balance (`_boxBal(box, tokenOut)`) right **after** this function is called.
    /// @return netSwappedOut the net amount of `tokenOut` swapped. If no swap occurs, returns 0.
    /// @dev `minSwapRate` check is performed only when an actual swap occurs.
    function _boxSwapToken(
        IPLoopPositionBox box,
        address tokenIn,
        uint256 tokenInBal,
        address tokenOut,
        uint256 minSwapRate,
        BoxApprovedCall memory swap
    ) internal returns (uint256 postTokenOutBal, uint256 netSwappedOut) {
        if (tokenIn == tokenOut) {
            return (tokenInBal, 0);
        }

        uint256 preTokenOutBal = _boxBal(box, tokenOut);
        if (swap.extRouter == address(0)) {
            return (preTokenOutBal, 0);
        }

        box.approveAndCall(
            ApprovedCall({ //
                token: tokenIn,
                amount: tokenInBal,
                approveTo: swap.approve,
                callTo: swap.extRouter,
                data: swap.callData
            }),
            address(box)
        );
        postTokenOutBal = _boxBal(box, tokenOut);
        netSwappedOut = postTokenOutBal - preTokenOutBal;

        require(netSwappedOut * PMath.ONE >= tokenInBal * minSwapRate, "PTLooper: swap below minSwapRate");
        emit TokenSwapped(box, tokenIn, tokenInBal, tokenOut, netSwappedOut);
    }

    /// @notice Only bridge between hubChain and spokeChain.
    function _boxBridgeToken(Session memory, BridgeData memory, address, uint256, address, uint256, bool)
        internal
        pure
    {
        revert("PTLooper: bridging not supported");
    }

    function _boxBal(IPLoopPositionBox box, address token) internal view returns (uint256) {
        return _balanceOf(address(box), token);
    }

    function _boxWithdraw(IPLoopPositionBox box, address to, address token, uint256 amount) internal {
        box.withdrawTo(to, token, amount);
    }

    function _onHub(BoxData memory bd) internal view returns (bool) {
        return bd.hubChainId == block.chainid;
    }

    function _onSpoke(BoxData memory bd) internal view returns (bool) {
        return bd.spokeChainId == block.chainid;
    }

    function _isCrossChain(BoxData memory bd) internal pure returns (bool) {
        return bd.hubChainId != bd.spokeChainId;
    }

    function _debtTokenHere(BoxData memory bd) internal view returns (address) {
        if (_onHub(bd)) return bd.hubDebtToken;
        if (_onSpoke(bd)) return bd.spokeDebtToken;
        revert("PTLooper: unsupported chainid");
    }

    function _ltvCheck(uint256 mmPtBal, uint256 mmDebtBal, uint256 mmOraclePtDebtRate, uint256 maxLTV) internal pure {
        require(mmDebtBal <= mmPtBal.mulDown(mmOraclePtDebtRate).mulDown(maxLTV), "PTLooper: maxLTV exceeded");
    }

    function _lendBorrowWithLTV(IncreasePositionRequest memory req, Session memory s, uint256 ptIn, uint256 debtOut)
        internal
    {
        MarketCtx memory ctx = _marketCtx(s);
        (uint256 netLent, uint256 mmPtBal) = s.spokeMM.lend(ctx, ptIn);
        (uint256 netBorrowed, uint256 mmDebtBal) = s.spokeMM.borrow(ctx, debtOut);
        uint256 rate = s.spokeMM.oraclePtDebtRate(ctx);
        _ltvCheck(mmPtBal, mmDebtBal, rate, req.postBorrowMaxLTV);
        emit MoneyMarketLentThenBorrowed(s.box, netLent, netBorrowed);
    }

    function _repayWithdrawWithLTV(DecreasePositionRequest memory req, Session memory s, uint256 debtIn, uint256 ptOut)
        internal
    {
        MarketCtx memory ctx = _marketCtx(s);
        (uint256 netRepaid, uint256 mmDebtBal) = s.spokeMM.repay(ctx, debtIn);
        (uint256 netWithdrawn, uint256 mmPtBal) = s.spokeMM.withdraw(ctx, ptOut);
        uint256 rate = s.spokeMM.oraclePtDebtRate(ctx);
        _ltvCheck(mmPtBal, mmDebtBal, rate, req.postWithdrawMaxLTV);
        emit MoneyMarketRepaidThenWithdrawn(s.box, netRepaid, netWithdrawn);
    }

    function claimMMRewards(
        ClaimMMRewardsMessage memory ms,
        bytes memory proposerSig,
        ClaimMMRewardsRequest memory req,
        bytes memory ownerSigIfFirstCall
    ) external onlyExecutor {
        (Session memory s, bytes32 requestHash) = _ensureSessionAndAuth(ms, req, proposerSig, ownerSigIfFirstCall);
        uint256[] memory claimedAmounts =
            s.spokeMM.claimRewards(_marketCtx(s), req.extRewardController, req.data, req.rewardTokens);
        emit RewardsClaimed(
            ms.permit.owner, ms.permit.boxId, requestHash, ms.permit.nonce, req.rewardTokens, claimedAmounts
        );
    }

    function _marketCtx(Session memory s) internal pure returns (MarketCtx memory) {
        return createMarketCtx(s.box, s.bd);
    }
}
