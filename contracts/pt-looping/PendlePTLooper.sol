// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {PMath} from "../core/libraries/math/PMath.sol";
import {ArrayLib} from "../core/libraries/ArrayLib.sol";
import {BoxCall, BoxData, IPLoopPositionBox} from "../interfaces/IPLoopPositionBox.sol";
import {IMoneyMarket, MarketCtx, createMarketCtx} from "../interfaces/IMoneyMarket.sol";
import {PTLooperBase} from "./PTLooperBase.sol";
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
        __EIP712_init(_EIP712Name(), _EIP712Version());
        __BoringOwnableV2_init(_owner);
    }

    function settleBox(address owner, bytes32 boxId, bool repayDebt, bool lendPt, address[] calldata tokensToOwner)
        external
        onlyExecutor
    {
        (IPLoopPositionBox box, IMoneyMarket mm, BoxData memory bd) =
            POSITION_BOX_FACTORY.deployPositionBoxAndMoneyMarket(owner, boxId);
        MarketCtx memory ctx = createMarketCtx(box, bd);

        if (repayDebt) {
            uint256 netRepaid = mm.repay(ctx, _boxBal(box, bd.spokeDebtToken));
            emit MoneyMarketRepaidThenWithdrawn(box, netRepaid, 0);
        }
        if (lendPt) {
            uint256 netLent = mm.lend(ctx, _boxBal(box, bd.spokePt));
            emit MoneyMarketLentThenBorrowed(box, netLent, 0);
        }

        for (uint256 i = 0; i < tokensToOwner.length; ++i) {
            uint256 amount = _boxBal(box, tokensToOwner[i]);
            _boxWithdraw(box, owner, tokensToOwner[i], amount);
            emit Withdrawn(owner, boxId, bytes32(0), tokensToOwner[i], amount);
        }
    }

    function increaseLoopPosition(IncreasePositionMessage memory ms, IncreasePositionRequest memory req)
        external
        onlyExecutor
    {
        Session memory s = _authorizedSession(ms.owner, req.header, _hashTyped(req));
        if (ms.flashAmount == 0) {
            _increase(ms, req, s);
        } else {
            _flashLoan(s, ms.flashAmount, abi.encodeCall(this.flashIncrease, (ms, req, s)));
        }
        // After the loan is paid back, so the checks see the final state.
        _checkLTV(s, req.postBorrowMaxLTV);
        POST_LOOP_STATE_CHECKER.check(s.marketCtx, ms.postStateCheckData);
    }

    /// @dev The iteration body. With a flash loan it runs inside the loan, and the box holds `ms.flashAmount`
    /// until Morpho pulls it back.
    function _increase(IncreasePositionMessage memory ms, IncreasePositionRequest memory req, Session memory s)
        internal
    {
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

        postDebtBal -= ms.flashAmount; // Morpho pulls the loan back after the body

        emit PositionIncreased(ms.owner, req.header.boxId, s.requestHash, preInBalance, netPtToMM, postDebtBal);
    }

    function _runHubIncrease(IncreasePositionMessage memory ms, IncreasePositionRequest memory req, Session memory s)
        internal
        returns (uint256 preInBalance, uint256 netPtToMM)
    {
        // Any iteration can set `swapInitToken`, so the owner can deposit more `initTokenIn` during a request.
        (address tokenIn, uint256 minSwapRate) =
            ms.swapInitToken ? (req.initTokenIn, req.initMinToPtSwapRate) : (s.bd.hubDebtToken, req.minDebtToPtSwapRate);
        minSwapRate = PMath.max(minSwapRate, ms.minSwapRate);

        preInBalance = _boxBal(s.box, tokenIn);

        _boxWithdraw(s.box, TREASURY, tokenIn, ms.fee);

        uint256 netIn = preInBalance - ms.fee;

        uint256 netPtSwappedOut;
        (netPtToMM, netPtSwappedOut) = _boxSwapToken(s.box, tokenIn, netIn, s.bd.hubPt, minSwapRate, ms.swap);
        if (req.isZeroPriceImpact) {
            _boxWithdraw(s.box, ms.owner, IPPrincipalToken(s.bd.hubPt).YT(), netPtSwappedOut);
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
        uint256 netLent = s.spokeMM.lend(s.marketCtx, netPtToMM);
        uint256 netBorrowed = s.spokeMM.borrow(s.marketCtx, ms.amountDebtBorrowed);
        emit MoneyMarketLentThenBorrowed(s.box, netLent, netBorrowed);

        postDebtBal = _boxBal(s.box, s.bd.spokeDebtToken);
        if (_isCrossChain(s.bd)) {
            _boxBridgeToken(
                s, ms.bridge, s.bd.spokeDebtToken, postDebtBal, s.bd.hubDebtToken, req.header.swapBridgeSlippage, false
            );
        }
    }

    function decreaseLoopPosition(DecreasePositionMessage memory ms, DecreasePositionRequest memory req)
        external
        onlyExecutor
    {
        Session memory s = _authorizedSession(ms.owner, req.header, _hashTyped(req));
        if (ms.flashAmount == 0) {
            _decrease(ms, req, s);
        } else {
            _flashLoan(s, ms.flashAmount, abi.encodeCall(this.flashDecrease, (ms, req, s)));
        }
        // After the loan is paid back, so the checks see the final state.
        _checkLTV(s, req.postWithdrawMaxLTV);
        POST_LOOP_STATE_CHECKER.check(s.marketCtx, ms.postStateCheckData);
    }

    /// @dev See `_increase`.
    function _decrease(DecreasePositionMessage memory ms, DecreasePositionRequest memory req, Session memory s)
        internal
    {
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

        postDebtBal -= ms.flashAmount; // Morpho pulls the loan back after the body

        emit PositionDecreased(ms.owner, req.header.boxId, s.requestHash, preDebtBal, netPtToSwap, postDebtBal);
    }

    function _runSpokeDecrease(DecreasePositionMessage memory ms, DecreasePositionRequest memory req, Session memory s)
        internal
        returns (uint256 preDebtBal, uint256 netPtToSwap)
    {
        preDebtBal = _boxBal(s.box, s.bd.spokeDebtToken);
        uint256 netRepaid = s.spokeMM.repay(s.marketCtx, preDebtBal);
        uint256 netWithdrawn = s.spokeMM.withdraw(s.marketCtx, ms.amountPtWithdrawn);
        emit MoneyMarketRepaidThenWithdrawn(s.box, netRepaid, netWithdrawn);

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
        uint256 minSwapRate = PMath.max(ms.minSwapRate, req.minPtToDebtSwapRate);
        (uint256 preFeeDebtBal,) = req.redeemWithPY
            ? _boxRedeemPYToToken(s.box, s.bd.hubPt, netPtToSwap, s.bd.hubDebtToken, minSwapRate, ms.swap)
            : _boxSwapToken(s.box, s.bd.hubPt, netPtToSwap, s.bd.hubDebtToken, minSwapRate, ms.swap);

        _boxWithdraw(s.box, TREASURY, s.bd.hubDebtToken, ms.fee);
        postDebtBal = preFeeDebtBal - ms.fee;

        if (_isCrossChain(s.bd)) {
            _boxBridgeToken(
                s, ms.bridge, s.bd.hubDebtToken, postDebtBal, s.bd.spokeDebtToken, req.header.swapBridgeSlippage, false
            );
        }
    }

    function swapBridgeWithdrawAll(SwapBridgeWithdrawAllMessage memory ms, SwapBridgeWithdrawAllRequest memory req)
        external
        onlyExecutor
    {
        Session memory s = _authorizedSession(ms.owner, req.header, _hashTyped(req));

        address tokenOutHere = _onHub(s.bd) ? req.hubTokenOut : req.dstTokenOut;

        uint256 postBal;
        {
            address tokenIn = _debtTokenHere(s.bd);
            (postBal,) = _boxSwapToken(s.box, tokenIn, _boxBal(s.box, tokenIn), tokenOutHere, ms.minSwapRate, ms.swap);
        }

        require(postBal >= req.minTokenWithdrawn, "PTLooper: insufficient token out");

        uint32 destChainId = req.receiveOnSpoke ? s.bd.spokeChainId : s.bd.hubChainId;
        if (destChainId != block.chainid) {
            _boxBridgeToken(s, ms.bridge, tokenOutHere, postBal, req.dstTokenOut, req.header.swapBridgeSlippage, false);
        } else {
            _boxWithdraw(s.box, ms.owner, tokenOutHere, postBal);
            emit Withdrawn(ms.owner, req.header.boxId, s.requestHash, tokenOutHere, postBal);
        }

        POST_LOOP_STATE_CHECKER.check(s.marketCtx, ms.postStateCheckData);
    }

    // ========== Flash loan ==========

    /// @dev Called after auth. The box borrows `amount` from Morpho and, inside the loan, calls back with `call`
    /// (`flashIncrease` / `flashDecrease`). `onlyFlashCall` lets only that exact call run, once, from that box.
    function _flashLoan(Session memory s, uint256 amount, bytes memory call) internal {
        require(!_isCrossChain(s.bd), "PTLooper: cross-chain flash loan");
        _flashCallHash = keccak256(call);
        emit FlashLoaned(s.box, s.bd.spokeDebtToken, amount);
        s.box.flashLoan(s.bd.spokeDebtToken, amount, call);
    }

    modifier onlyFlashCall(IPLoopPositionBox box) {
        require(
            msg.sender == address(box) && keccak256(msg.data) == _flashCallHash, "PTLooper: unauthorized flash call"
        );
        _flashCallHash = bytes32(0);
        _;
    }

    /// @dev Runs inside the loan. The auth ran in `increaseLoopPosition`.
    function flashIncrease(IncreasePositionMessage memory ms, IncreasePositionRequest memory req, Session memory s)
        external
        onlyFlashCall(s.box)
    {
        _increase(ms, req, s);
    }

    /// @dev Runs inside the loan. The auth ran in `decreaseLoopPosition`.
    function flashDecrease(DecreasePositionMessage memory ms, DecreasePositionRequest memory req, Session memory s)
        external
        onlyFlashCall(s.box)
    {
        _decrease(ms, req, s);
    }

    /// @param tokenInBal the box's whole `tokenIn` balance before the call.
    /// @return postTokenOutBal the box's whole `tokenOut` balance after the call.
    /// @return netSwappedOut the `tokenOut` that the swap gave. 0 with no swap.
    function _boxSwapToken(
        IPLoopPositionBox box,
        address tokenIn,
        uint256 tokenInBal,
        address tokenOut,
        uint256 minSwapRate,
        BoxApprovedCall memory swap
    ) internal returns (uint256 postTokenOutBal, uint256 netSwappedOut) {
        if (tokenIn == tokenOut) return (tokenInBal, 0);

        BoxCall memory call = tokenIn == NATIVE
            ? _toBoxCall(swap, new address[](0), new uint256[](0), tokenInBal)
            : _toBoxCall(swap, ArrayLib.create(tokenIn), ArrayLib.create(tokenInBal), 0);

        (postTokenOutBal, netSwappedOut) = _boxExecSwap(box, tokenInBal, tokenOut, minSwapRate, call);

        if (netSwappedOut > 0) emit TokenSwapped(box, tokenIn, tokenInBal, tokenOut, netSwappedOut);
    }

    /// @dev PT + YT to `tokenOut`. The box approves min(PT, YT) of each; the router must spend them 1:1.
    /// @param ptBal the box's whole `pt` balance before the call.
    function _boxRedeemPYToToken(
        IPLoopPositionBox box,
        address pt,
        uint256 ptBal,
        address tokenOut,
        uint256 minSwapRate,
        BoxApprovedCall memory swap
    ) internal returns (uint256 postTokenOutBal, uint256 netSwappedOut) {
        address yt = IPPrincipalToken(pt).YT();
        uint256 ytBal = _boxBal(box, yt);
        uint256 netPyIn = PMath.min(ytBal, ptBal);

        BoxCall memory call = _toBoxCall(swap, ArrayLib.create(pt, yt), ArrayLib.create(netPyIn, netPyIn), 0);
        (postTokenOutBal, netSwappedOut) = _boxExecSwap(box, netPyIn, tokenOut, minSwapRate, call);

        // An underflow (the router sent PT or YT to the box) reverts on purpose.
        require(ytBal - _boxBal(box, yt) == ptBal - _boxBal(box, pt), "PTLooper: PY redeem mismatch");

        if (netSwappedOut > 0) emit PYRedeemed(box, pt, netPyIn, tokenOut, netSwappedOut);
    }

    /// @dev No swap, and no rate check, when `call.extRouter == address(0)`.
    function _boxExecSwap(
        IPLoopPositionBox box,
        uint256 netIn,
        address tokenOut,
        uint256 minSwapRate,
        BoxCall memory call
    ) internal returns (uint256 postTokenOutBal, uint256 netSwappedOut) {
        uint256 preTokenOutBal = _boxBal(box, tokenOut);
        if (call.extRouter == address(0)) return (preTokenOutBal, 0);

        box.approveAndCall(call, address(box));
        postTokenOutBal = _boxBal(box, tokenOut);
        netSwappedOut = postTokenOutBal - preTokenOutBal;

        require(netSwappedOut * PMath.ONE >= netIn * minSwapRate, "PTLooper: swap below minSwapRate");
    }

    function _toBoxCall(
        BoxApprovedCall memory swap,
        address[] memory tokens,
        uint256[] memory amounts,
        uint256 nativeAmount
    ) internal pure returns (BoxCall memory) {
        return BoxCall({
            tokens: tokens,
            amounts: amounts,
            nativeAmount: nativeAmount,
            approve: swap.approve,
            extRouter: swap.extRouter,
            callData: swap.callData
        });
    }

    /// @dev Stub until cross-chain lands. Only a cross-chain box gets here.
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
        if (amount == 0) return;
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

    /// @dev No debt, or no money market on this chain: the check passes with no oracle read.
    function _checkLTV(Session memory s, uint256 maxLTV) internal {
        if (address(s.spokeMM) == address(0)) return;
        uint256 debt = s.spokeMM.debtBalance(s.marketCtx);
        if (debt == 0) return;
        uint256 colat = s.spokeMM.collateralBalance(s.marketCtx);
        uint256 ptDebtRate = s.spokeMM.oraclePtDebtRate(s.marketCtx);
        require(debt <= colat.mulDown(ptDebtRate).mulDown(maxLTV), "PTLooper: maxLTV exceeded");
    }
}
