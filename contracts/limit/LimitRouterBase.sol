// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "../interfaces/IPLimitRouter.sol";
import "../core/libraries/BoringOwnableUpgradeable.sol";
import "../core/libraries/TokenHelper.sol";
import "../interfaces/IStandardizedYield.sol";
import "./helpers/NonceManager.sol";
import "../interfaces/IWETH.sol";
import {LimitMathCore as LimitMath} from "./LimitMathCore.sol";

abstract contract LimitRouterBase is
    EIP712Upgradeable,
    IPLimitRouter,
    BoringOwnableUpgradeable,
    NonceManager,
    TokenHelper
{
    using SafeERC20 for IERC20;
    using PMath for uint256;

    bytes32 internal constant LIMIT_ORDER_TYPEHASH =
        keccak256(
            "Order(uint256 salt,uint256 expiry,uint256 nonce,uint8 orderType,address token,address YT,address maker,address receiver,uint256 makingAmount,uint256 lnImpliedRate,uint256 failSafeRate,bytes permit)"
        );

    uint128 internal constant _ORDER_DOES_NOT_EXIST = 0;
    uint128 internal constant _ORDER_FILLED = 1;
    uint256 internal constant NEW_PRIME = 12421;
    bytes private constant EMPTY_BYTES = abi.encode();

    address public feeRecipient;

    // YT => lnFeeRateRoot // not to be accessed directly
    mapping(address => uint256) internal __lnFeeRateRoot;

    address private immutable WNATIVE;

    mapping(bytes32 => OrderStatus) internal _status;

    address public ownerHelper;

    uint256[99] private __gap;

    modifier onlyHelperAndOwner() {
        require(msg.sender == ownerHelper || msg.sender == owner, "not allowed");
        _;
    }

    constructor(address _WNATIVE) {
        WNATIVE = _WNATIVE;
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    function initialize(address _feeRecipient) external initializer {
        __BoringOwnable_init();
        __EIP712_init("Pendle Limit Order Protocol", "1");
        setFeeRecipient(_feeRecipient);
    }

    function fill(
        FillOrderParams[] memory params,
        address receiver,
        uint256 maxTaking,
        bytes calldata /*optData*/,
        bytes memory callback
    ) external returns (uint256 actualMaking, uint256 actualTaking, uint256 totalFee, bytes memory callbackReturn) {
        params = _validateSkipSigAndFilterOrders(params);
        if (params.length == 0) return fillNoOrders(callback);

        OrderType orderType = params[0].order.orderType;
        if (orderType == OrderType.SY_FOR_PT || orderType == OrderType.SY_FOR_YT) {
            return fillTokenForPY(Args(orderType, params, receiver, maxTaking, callback));
        } else {
            return fillPYForToken(Args(orderType, params, receiver, maxTaking, callback));
        }
    }

    // ----------------- Core logic -----------------

    struct Args {
        OrderType orderType;
        FillOrderParams[] params;
        address receiver;
        uint256 maxTaking;
        bytes callback;
    }

    function fillNoOrders(
        bytes memory callback
    ) internal returns (uint256 actualMaking, uint256 actualTaking, uint256 totalFee, bytes memory callbackReturn) {
        callbackReturn = callbackIfNeeded(0, 0, 0, callback);
        return (0, 0, 0, callbackReturn);
    }

    function fillTokenForPY(
        Args memory a
    ) internal returns (uint256 actualMaking, uint256 actualTaking, uint256 totalFee, bytes memory callbackReturn) {
        (address SY, address PT, address YT, bytes32[] memory orderHashes) = _checkSig_updMakingAndStatus(a.params);

        // Token => This
        uint256[] memory fromMakers = _transferFromMakers_mintSy_updMakings(SY, a.params);

        FillResults memory out = LimitMath.calcBatch(a.params, YT, getLnFeeRateRoot(YT));
        (actualMaking, actualTaking, totalFee) = (out.totalMaking - out.totalFee, out.totalTaking, out.totalFee);

        require(actualTaking <= a.maxTaking, "LOP: maxTaking exceeded");

        // This => Taker
        _transferOut(SY, a.receiver, actualMaking);

        // callback to Taker
        callbackReturn = callbackIfNeeded(actualMaking, actualTaking, totalFee, a.callback);

        // Taker => Makers
        address pyToMaker = (a.orderType == OrderType.SY_FOR_PT) ? PT : YT;
        _transferToMakers(IERC20(pyToMaker), msg.sender, a.params, out.netTakings);

        // This => Fee
        _transferOut(SY, feeRecipient, totalFee);

        // toMakers == netTakings
        _emitEvents(a.params, orderHashes, fromMakers, out.netTakings, out.netFees, out.notionalVolumes);
    }

    function fillPYForToken(
        Args memory a
    ) internal returns (uint256 actualMaking, uint256 actualTaking, uint256 totalFee, bytes memory callbackReturn) {
        (address SY, address PT, address YT, bytes32[] memory orderHashes) = _checkSig_updMakingAndStatus(a.params);

        FillResults memory out = LimitMath.calcBatch(a.params, YT, getLnFeeRateRoot(YT));
        (actualMaking, actualTaking, totalFee) = (out.totalMaking, out.totalTaking + out.totalFee, out.totalFee);

        require(actualTaking <= a.maxTaking, "LOP: maxTaking exceeded");

        // Makers => Taker
        address pyFromMaker = (a.orderType == OrderType.PT_FOR_SY) ? PT : YT;
        _transferFromMakers(IERC20(pyFromMaker), a.params, a.receiver, out.netMakings);

        // callback to Taker
        callbackReturn = callbackIfNeeded(actualMaking, actualTaking, totalFee, a.callback);

        // Taker => This
        _transferFrom(IERC20(SY), msg.sender, address(this), actualTaking);

        // This => Makers
        uint256[] memory toMakers = _redeemSy_transferToMakers(SY, a.params, out.netTakings);

        // This => Fee
        _transferOut(SY, feeRecipient, totalFee);

        // fromMakers == netMakings
        _emitEvents(a.params, orderHashes, out.netMakings, toMakers, out.netFees, out.notionalVolumes);
    }

    // ----------------- verify & convert functions -----------------
    function _validateSkipSigAndFilterOrders(
        FillOrderParams[] memory params
    ) internal view returns (FillOrderParams[] memory res) {
        uint256 len = params.length;
        require(len != 0, "LOP: empty batch");

        (address YT, OrderType orderType) = (params[0].order.YT, params[0].order.orderType);
        require(block.timestamp < IPYieldToken(YT).expiry(), "LOP: PY expired");

        uint256 skipped = 0;
        for (uint256 i = 0; i < len; i++) {
            Order memory order = params[i].order;
            require(order.orderType == orderType && order.YT == YT, "LOP: mismatch types");

            if (!(block.timestamp < order.expiry && order.nonce >= nonce[order.maker])) {
                skipped++;
                params[i].signature = EMPTY_BYTES;
            }
        }

        res = new FillOrderParams[](len - skipped);
        uint256 iter = 0;
        for (uint256 i = 0; i < len; i++) {
            if (params[i].signature.length != 0) {
                res[iter] = params[i];
                iter++;
            }
        }
    }

    function _checkSig_updMakingAndStatus(
        FillOrderParams[] memory params
    ) internal returns (address SY, address PT, address YT, bytes32[] memory orderHashes) {
        uint256 len = params.length;
        orderHashes = new bytes32[](len);

        for (uint256 i = 0; i < len; i++) {
            FillOrderParams memory param = params[i];

            (bytes32 orderHash, uint256 remainingMakerAmount, uint256 filledMakerAmount) = _checkSig(
                param.order,
                param.signature
            );
            uint256 netMaking = PMath.min(param.makingAmount, remainingMakerAmount);

            unchecked {
                remainingMakerAmount = remainingMakerAmount - netMaking;
                _status[orderHash] = OrderStatus({
                    remaining: (remainingMakerAmount + 1).Uint128(),
                    filledAmount: (filledMakerAmount + netMaking).Uint128()
                });
            }

            param.makingAmount = netMaking;

            orderHashes[i] = orderHash;
        }

        YT = params[0].order.YT;
        SY = IPYieldToken(YT).SY();
        PT = IPYieldToken(YT).PT();
    }

    function _emitEvents(
        FillOrderParams[] memory params,
        bytes32[] memory hashes,
        uint256[] memory fromMakers,
        uint256[] memory toMakers,
        uint256[] memory netFees,
        uint256[] memory notionalVolumes
    ) internal {
        uint256 len = hashes.length;

        for (uint256 i = 0; i < len; i++) {
            Order memory order = params[i].order;
            emit OrderFilledV2(
                hashes[i],
                order.orderType,
                order.YT,
                order.token,
                fromMakers[i],
                toMakers[i],
                netFees[i],
                notionalVolumes[i],
                params[i].order.maker,
                msg.sender
            );
        }
    }

    function callbackIfNeeded(
        uint256 actualMaking,
        uint256 actualTaking,
        uint256 totalFee,
        bytes memory callback
    ) internal returns (bytes memory callbackReturn) {
        if (callback.length > 0) {
            callbackReturn = IPLimitRouterCallback(msg.sender).limitRouterCallback(
                actualMaking,
                actualTaking,
                totalFee,
                callback
            );
        }
    }

    function _checkSig(
        Order memory order,
        bytes memory signature
    )
        public
        view
        returns (
            bytes32,
            /*orderHash*/
            uint256,
            /*remainingMakerAmount*/
            uint256 /*filledMakerAmount*/
        )
    {
        bytes32 orderHash = hashOrder(order);
        OrderStatus memory status = _status[orderHash];
        (uint256 remainingMakerAmount, uint256 filledMakerAmount) = (status.remaining, status.filledAmount);

        if (remainingMakerAmount == _ORDER_DOES_NOT_EXIST) {
            require(SignatureChecker.isValidSignatureNow(order.maker, orderHash, signature), "LOP: bad signature");

            remainingMakerAmount = order.makingAmount;
        } else {
            unchecked {
                remainingMakerAmount -= 1;
            }
        }

        return (orderHash, remainingMakerAmount, filledMakerAmount);
    }

    // ----------------- simple helper functions functions -----------------

    function _transferFromMakers_mintSy_updMakings(
        address SY,
        FillOrderParams[] memory params
    ) internal returns (uint256[] memory fromMakers) {
        uint256 len = params.length;
        fromMakers = new uint256[](len);

        for ((uint256 l, uint256 r) = (0, 0); l < len; l = r) {
            address sharedToken = params[l].order.token;
            uint256 totalMaking = 0;
            for (; r < len && params[r].order.token == sharedToken; r++) {
                _transferIn(sharedToken, params[r].order.maker, params[r].makingAmount);
                totalMaking += params[r].makingAmount;
                fromMakers[r] = params[r].makingAmount;
            }

            if (sharedToken == SY || totalMaking == 0) continue;

            uint256 totalSy = __mintSy_Single(SY, sharedToken, totalMaking);
            for (uint256 i = l; i < r; i++) {
                uint256 netToken = params[i].makingAmount;
                uint256 netSy = (netToken * totalSy) / totalMaking;

                if (_isNewOrder(params[i].order)) {
                    require(netToken.mulDown(params[i].order.failSafeRate) <= netSy, "LOP: fail safe");
                }

                params[i].makingAmount = netSy;
            }
        }
    }

    function __mintSy_Single(address SY, address token, uint256 netTokenIn) private returns (uint256 netSyOut) {
        if (token == WNATIVE && !IStandardizedYield(SY).isValidTokenIn(WNATIVE)) {
            _wrap_unwrap_ETH(WNATIVE, NATIVE, netTokenIn);
            token = NATIVE;
        }
        _safeApproveInf(token, SY);
        return
            IStandardizedYield(SY).deposit{value: token == NATIVE ? netTokenIn : 0}(
                address(this),
                token,
                netTokenIn,
                0
            );
    }

    function _redeemSy_transferToMakers(
        address SY,
        FillOrderParams[] memory params,
        uint256[] memory netSyOuts
    ) internal returns (uint256[] memory toMakers) {
        uint256 len = params.length;
        toMakers = new uint256[](len);

        for ((uint256 l, uint256 r) = (0, 0); l < len; l = r) {
            address sharedToken = params[l].order.token;
            uint256 totalSy = 0;

            for (; r < len && __stillShared(sharedToken, params[r].order.token); r++) {
                totalSy += netSyOuts[r];
            }

            if (totalSy == 0) continue;

            if (sharedToken == SY) {
                for (uint256 i = l; i < r; i++) {
                    _transferOut(SY, params[i].order.receiver, netSyOuts[i]);
                    toMakers[i] = netSyOuts[i];
                }
                continue;
            }

            if (r - l == 1) {
                toMakers[l] = __redeemSy_Single(params[l].order.receiver, SY, sharedToken, netSyOuts[l]);
            } else {
                uint256 totalToken = __redeemSy_Single(address(this), SY, sharedToken, totalSy);
                for (uint256 i = l; i < r; i++) {
                    address token = params[i].order.token;
                    toMakers[i] = (netSyOuts[i] * totalToken) / totalSy;
                    if (sharedToken != token) {
                        // WNATIVE case
                        _wrap_unwrap_ETH(sharedToken, token, toMakers[i]);
                    }
                    _transferOut(token, params[i].order.receiver, toMakers[i]);
                }
            }

            for (uint256 i = l; i < r; i++) {
                if (_isNewOrder(params[i].order)) {
                    uint256 netSy = netSyOuts[i];
                    uint256 netToken = toMakers[i];

                    require(netSy.mulDown(params[i].order.failSafeRate) <= netToken, "LOP: fail safe");
                }
            }
        }
    }

    function __stillShared(address currentShared, address nextToken) private view returns (bool) {
        return
            (currentShared == nextToken) ||
            (currentShared == NATIVE && nextToken == WNATIVE) ||
            (currentShared == WNATIVE && nextToken == NATIVE);
    }

    function __redeemSy_Single(
        address receiver,
        address SY,
        address tokenOut,
        uint256 netSyIn
    ) private returns (uint256 netTokenOut) {
        if (tokenOut == NATIVE || tokenOut == WNATIVE) {
            address otherToken = tokenOut == NATIVE ? WNATIVE : NATIVE;
            address tokenRedeemSy = IStandardizedYield(SY).isValidTokenOut(tokenOut) ? tokenOut : otherToken;

            netTokenOut = IStandardizedYield(SY).redeem(address(this), netSyIn, tokenRedeemSy, 0, false);

            if (tokenOut != tokenRedeemSy) {
                _wrap_unwrap_ETH(tokenRedeemSy, tokenOut, netTokenOut);
            }

            if (receiver != address(this)) {
                _transferOut(tokenOut, receiver, netTokenOut);
            }
        } else {
            return IStandardizedYield(SY).redeem(receiver, netSyIn, tokenOut, 0, false);
        }
    }

    // ! Allow self-fill of orders
    function _transferFromMakers(
        IERC20 token,
        FillOrderParams[] memory params,
        address to,
        uint256[] memory netIn
    ) internal {
        uint256 len = params.length;
        for (uint256 i = 0; i < len; i++) {
            if (params[i].order.maker == to) continue;
            token.safeTransferFrom(params[i].order.maker, to, netIn[i]);
        }
    }

    function _transferToMakers(
        IERC20 token,
        address payer,
        FillOrderParams[] memory params,
        uint256[] memory netOut
    ) internal {
        uint256 len = params.length;
        for (uint256 i = 0; i < len; i++) {
            if (payer == params[i].order.receiver) continue;
            token.safeTransferFrom(payer, params[i].order.receiver, netOut[i]);
        }
    }

    function _isNewOrder(Order memory order) internal pure returns (bool) {
        return order.salt % NEW_PRIME == 0;
    }

    function hashOrder(Order memory order) public view returns (bytes32) {
        StaticOrder memory staticOrder;
        assembly {
            staticOrder := order
        }
        return _hashTypedDataV4(keccak256(abi.encode(LIMIT_ORDER_TYPEHASH, staticOrder, keccak256(order.permit))));
    }

    function getLnFeeRateRoot(address YT) public view returns (uint256 res) {
        res = __lnFeeRateRoot[YT];
        require(res > 0, "LOP: fee not set");
    }

    // ----------------- Owner -----------------

    function setFeeRecipient(address _feeRecipient) public onlyOwner {
        feeRecipient = _feeRecipient;
    }

    function setOwnerHelper(address _helper) public onlyOwner {
        ownerHelper = _helper;
    }

    function setLnFeeRateRoots(address[] memory YTs, uint256[] memory lnFeeRateRoots) public onlyHelperAndOwner {
        uint256 len = YTs.length;
        require(len == lnFeeRateRoots.length, "LOP: length mismatch");

        if (msg.sender == ownerHelper) {
            _requireFeeNotSet(YTs);
        }

        for (uint256 i = 0; i < len; i++) {
            require(lnFeeRateRoots[i] > 0, "LOP: zero fee not allowed");
            __lnFeeRateRoot[YTs[i]] = lnFeeRateRoots[i];
        }
    }

    function _requireFeeNotSet(address[] memory YTs) internal view {
        for (uint256 i = 0; i < YTs.length; i++) {
            require(__lnFeeRateRoot[YTs[i]] == 0, "LOP: fee already set");
        }
    }
}
