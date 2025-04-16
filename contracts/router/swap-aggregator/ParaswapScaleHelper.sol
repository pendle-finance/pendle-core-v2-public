// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ParaswapScaleHelper {
    function _paraswapScaling(bytes calldata rawCallData, uint256 amountIn)
        internal
        pure
        returns (bytes memory scaledCallData)
    {
        bytes4 selector = bytes4(rawCallData[:4]);
        bytes calldata dataToDecode = rawCallData[4:];

        // Handle Generic Swap
        if (selector == IAugustusV6.swapExactAmountIn.selector) {
            (
                address executor,
                IAugustusV6.GenericData memory swapData,
                uint256 partnerAndFee,
                bytes memory permit,
                bytes memory executorData
            ) = abi.decode(dataToDecode, (address, IAugustusV6.GenericData, uint256, bytes, bytes));

            // Direct scaling calculation
            swapData.toAmount = swapData.toAmount * amountIn / swapData.fromAmount;
            swapData.quotedAmount = swapData.quotedAmount * amountIn / swapData.fromAmount;
            swapData.fromAmount = amountIn;

            return abi.encodeWithSelector(selector, executor, swapData, partnerAndFee, permit, executorData);
        } 
        
        // Handle UniswapV2
        else if (selector == IAugustusV6.swapExactAmountInOnUniswapV2.selector) {
            (
                address executor,
                IAugustusV6.UniswapV2Data memory uniData,
                uint256 partnerAndFee,
                bytes memory permit
            ) = abi.decode(dataToDecode, (address, IAugustusV6.UniswapV2Data, uint256, bytes));

            // Direct scaling calculation
            uniData.toAmount = uniData.toAmount * amountIn / uniData.fromAmount;
            uniData.quotedAmount = uniData.quotedAmount * amountIn / uniData.fromAmount;
            uniData.fromAmount = amountIn;

            return abi.encodeWithSelector(selector, executor, uniData, partnerAndFee, permit);
        } 
        
        // Handle UniswapV3
        else if (selector == IAugustusV6.swapExactAmountInOnUniswapV3.selector) {
            (
                address executor,
                IAugustusV6.UniswapV3Data memory uniV3Data,
                uint256 partnerAndFee,
                bytes memory permit
            ) = abi.decode(dataToDecode, (address, IAugustusV6.UniswapV3Data, uint256, bytes));

            // Direct scaling calculation
            uniV3Data.toAmount = uniV3Data.toAmount * amountIn / uniV3Data.fromAmount;
            uniV3Data.quotedAmount = uniV3Data.quotedAmount * amountIn / uniV3Data.fromAmount;
            uniV3Data.fromAmount = amountIn;

            return abi.encodeWithSelector(selector, executor, uniV3Data, partnerAndFee, permit);
        } 
        
        // Handle BalancerV2
        else if (selector == IAugustusV6.swapExactAmountInOnBalancerV2.selector) {
            (
                address executor,
                IAugustusV6.BalancerV2Data memory balancerData,
                uint256 partnerAndFee,
                bytes memory permit,
                bytes memory data
            ) = abi.decode(dataToDecode, (address, IAugustusV6.BalancerV2Data, uint256, bytes, bytes));

            // Direct scaling calculation
            balancerData.toAmount = balancerData.toAmount * amountIn / balancerData.fromAmount;
            balancerData.quotedAmount = balancerData.quotedAmount * amountIn / balancerData.fromAmount;
            balancerData.fromAmount = amountIn;

            return abi.encodeWithSelector(selector, executor, balancerData, partnerAndFee, permit, data);
        } 
        
        // Handle CurveV1
        else if (selector == IAugustusV6.swapExactAmountInOnCurveV1.selector) {
            (
                address executor,
                IAugustusV6.CurveV1Data memory curveV1Data,
                uint256 partnerAndFee,
                bytes memory permit
            ) = abi.decode(dataToDecode, (address, IAugustusV6.CurveV1Data, uint256, bytes));

            // Direct scaling calculation
            curveV1Data.toAmount = curveV1Data.toAmount * amountIn / curveV1Data.fromAmount;
            curveV1Data.quotedAmount = curveV1Data.quotedAmount * amountIn / curveV1Data.fromAmount;
            curveV1Data.fromAmount = amountIn;

            return abi.encodeWithSelector(selector, executor, curveV1Data, partnerAndFee, permit);
        } 
        
        // Handle CurveV2
        else if (selector == IAugustusV6.swapExactAmountInOnCurveV2.selector) {
            (
                address executor,
                IAugustusV6.CurveV2Data memory curveV2Data,
                uint256 partnerAndFee,
                bytes memory permit
            ) = abi.decode(dataToDecode, (address, IAugustusV6.CurveV2Data, uint256, bytes));

            // Direct scaling calculation
            curveV2Data.toAmount = curveV2Data.toAmount * amountIn / curveV2Data.fromAmount;
            curveV2Data.quotedAmount = curveV2Data.quotedAmount * amountIn / curveV2Data.fromAmount;
            curveV2Data.fromAmount = amountIn;

            return abi.encodeWithSelector(selector, executor, curveV2Data, partnerAndFee, permit);
        } 
        
        // Handle AugustusRFQ
        else if (selector == IAugustusV6.swapOnAugustusRFQTryBatchFill.selector) {
            (
                address executor,
                IAugustusV6.AugustusRFQData memory augustusData,
                IAugustusV6.OrderInfo[] memory orders,
                bytes memory permit
            ) = abi.decode(dataToDecode, (address, IAugustusV6.AugustusRFQData, IAugustusV6.OrderInfo[], bytes));
            
            // Direct scaling calculation
            augustusData.toAmount = augustusData.toAmount * amountIn / augustusData.fromAmount;
            augustusData.fromAmount = amountIn;

            return abi.encodeWithSelector(selector, executor, augustusData, orders, permit);
        } 
        
        // Handle MakerPSM
        else if (selector == IAugustusV6.swapExactAmountInOutOnMakerPSM.selector) {
            (
                address executor,
                IAugustusV6.MakerPSMData memory makerPSMData,
                bytes memory permit
            ) = abi.decode(dataToDecode, (address, IAugustusV6.MakerPSMData, bytes));

            // Direct scaling calculation
            makerPSMData.toAmount = makerPSMData.toAmount * amountIn / makerPSMData.fromAmount;
            makerPSMData.fromAmount = amountIn;

            return abi.encodeWithSelector(selector, executor, makerPSMData, permit);
        }

        revert("ParaswapScaleHelper: Unsupported swap selector");
    }
}

interface IAugustusV6 {
    // ============ Generic Swap ============
    struct GenericData {
        IERC20 srcToken;
        IERC20 destToken;
        uint256 fromAmount;
        uint256 toAmount;
        uint256 quotedAmount;
        bytes32 metadata;
        address payable beneficiary;
    }

    function swapExactAmountIn(
        address executor,
        GenericData calldata swapData,
        uint256 partnerAndFee,
        bytes calldata permit,
        bytes calldata executorData
    ) external payable;

    // ============ UniswapV2 Swap ============
    struct UniswapV2Data {
        IERC20 srcToken;
        IERC20 destToken;
        uint256 fromAmount;
        uint256 toAmount;
        uint256 quotedAmount;
        bytes32 metadata;
        address payable beneficiary;
        bytes pools;
    }

    function swapExactAmountInOnUniswapV2(
        address executor,
        UniswapV2Data calldata uniData,
        uint256 partnerAndFee,
        bytes calldata permit
    ) external payable returns (uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);

    // ============ UniswapV3 Swap ============
    struct UniswapV3Data {
        IERC20 srcToken;
        IERC20 destToken;
        uint256 fromAmount;
        uint256 toAmount;
        uint256 quotedAmount;
        bytes32 metadata;
        address payable beneficiary;
        bytes pools;
    }

    function swapExactAmountInOnUniswapV3(
        address executor,
        UniswapV3Data calldata uniData,
        uint256 partnerAndFee,
        bytes calldata permit
    ) external payable returns (uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);

    // ============ BalancerV2 Swap ============
    struct BalancerV2Data {
        uint256 fromAmount;
        uint256 toAmount;
        uint256 quotedAmount;
        bytes32 metadata;
        uint256 beneficiaryAndApproveFlag;
    }

    function swapExactAmountInOnBalancerV2(
        address executor,
        BalancerV2Data calldata balancerData,
        uint256 partnerAndFee,
        bytes calldata permit,
        bytes calldata data
    ) external payable returns (uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);

    // ============ CurveV1 Swap ============
    struct CurveV1Data {
        uint256 curveData;
        uint256 curveAssets;
        IERC20 srcToken;
        IERC20 destToken;
        uint256 fromAmount;
        uint256 toAmount;
        uint256 quotedAmount;
        bytes32 metadata;
        address payable beneficiary;
    }

    function swapExactAmountInOnCurveV1(
        address executor,
        CurveV1Data calldata curveV1Data,
        uint256 partnerAndFee,
        bytes calldata permit
    ) external payable returns (uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);

    // ============ CurveV2 Swap ============
    struct CurveV2Data {
        uint256 curveData;
        uint256 i;
        uint256 j;
        address poolAddress;
        IERC20 srcToken;
        IERC20 destToken;
        uint256 fromAmount;
        uint256 toAmount;
        uint256 quotedAmount;
        bytes32 metadata;
        address payable beneficiary;
    }

    function swapExactAmountInOnCurveV2(
        address executor,
        CurveV2Data calldata curveV2Data,
        uint256 partnerAndFee,
        bytes calldata permit
    ) external payable returns (uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);

    // ============ AugustusRFQ Swap ============
    struct AugustusRFQData {
        uint256 fromAmount;
        uint256 toAmount;
        uint8 wrapApproveDirection;
        bytes32 metadata;
        address payable beneficiary;
    }
    
    struct Order {
        uint256 nonceAndMeta;
        uint128 expiry;
        address makerAsset;
        address takerAsset;
        address maker;
        address taker;
        uint256 makerAmount;
        uint256 takerAmount;
    }

    struct OrderInfo {
        Order order;
        bytes signature;
        uint256 takerTokenFillAmount;
        bytes permitTakerAsset;
        bytes permitMakerAsset;
    }

    function swapOnAugustusRFQTryBatchFill(
        address executor,
        AugustusRFQData calldata data,
        OrderInfo[] calldata orders,
        bytes calldata permit
    ) external payable returns (uint256 spentAmount, uint256 receivedAmount);

    // ============ MakerPSM Swap ============
    struct MakerPSMData {
        IERC20 srcToken;
        IERC20 destToken;
        uint256 fromAmount;
        uint256 toAmount;
        uint256 toll;
        uint256 to18ConversionFactor;
        address exchange;
        address gemJoinAddress;
        bytes32 metadata;
        uint256 beneficiaryDirectionApproveFlag;
    }

    function swapExactAmountInOutOnMakerPSM(
        address executor,
        MakerPSMData calldata makerPSMData,
        bytes calldata permit
    ) external returns (uint256 spentAmount, uint256 receivedAmount);
}