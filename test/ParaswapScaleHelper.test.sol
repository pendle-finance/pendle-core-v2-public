// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/router/swap-aggregator/ParaswapScaleHelper.sol";

contract ParaswapScaleHelperTestHarness is ParaswapScaleHelper {
    function exposedParaswapScaling(
        bytes calldata rawCallData,
        uint256 amountIn
    ) external pure returns (bytes memory) {
        return _paraswapScaling(rawCallData, amountIn);
    }
}

contract ParaswapScaleHelperTest is Test {
    ParaswapScaleHelperTestHarness public helper;

    // Common test values
    address constant TOKEN_SRC = address(0x9D39A5DE30e57443BfF2A8307A4256c8797A3497);
    address constant TOKEN_DEST = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address constant EXECUTOR = address(0x6A000F20005980200259B80c5102003040001068);
    address constant BENEFICIARY = address(0x1);
    
    uint256 constant ORIGINAL_AMOUNT = 1000;
    uint256 constant SCALED_AMOUNT = 2000; // 2x
    uint256 constant EXPECTED_TO_AMOUNT = 2000;
    uint256 constant EXPECTED_QUOTED_AMOUNT = 2100;
    uint256 constant EXPECTED_SCALED_TO_AMOUNT = 4000; // 2x
    uint256 constant EXPECTED_SCALED_QUOTED_AMOUNT = 4200; // 2x
    
    bytes constant PERMIT = "01";
    bytes constant EXECUTOR_DATA = "02";
    uint256 constant PARTNER_AND_FEE = 123;

    function setUp() public {
        helper = new ParaswapScaleHelperTestHarness();
    }

    function test_swapExactAmountInGeneric() public {
        // Create a sample GenericData struct
        IAugustusV6.GenericData memory data = IAugustusV6.GenericData({
            srcToken: IERC20(TOKEN_SRC),
            destToken: IERC20(TOKEN_DEST),
            fromAmount: ORIGINAL_AMOUNT,
            toAmount: EXPECTED_TO_AMOUNT,
            quotedAmount: EXPECTED_QUOTED_AMOUNT,
            metadata: bytes32(0),
            beneficiary: payable(BENEFICIARY)
        });

        // Create the original calldata
        bytes memory rawCallData = abi.encodeWithSelector(
            IAugustusV6.swapExactAmountIn.selector,
            EXECUTOR,
            data,
            PARTNER_AND_FEE,
            PERMIT,
            EXECUTOR_DATA
        );

        // Scale the amount by 2x
        bytes memory scaledCallData = helper.exposedParaswapScaling(rawCallData, SCALED_AMOUNT);

        // Decode the scaled calldata and verify the amounts
        bytes memory callDataWithoutSelector = new bytes(scaledCallData.length - 4);
        for (uint i = 0; i < callDataWithoutSelector.length; i++) {
            callDataWithoutSelector[i] = scaledCallData[i + 4];
        }
        
        (
            address decodedExecutor,
            IAugustusV6.GenericData memory decodedData,
            uint256 decodedPartnerAndFee,
            bytes memory decodedPermit,
            bytes memory decodedExecutorData
        ) = abi.decode(
            callDataWithoutSelector,
            (address, IAugustusV6.GenericData, uint256, bytes, bytes)
        );

        // Check that the amounts have been scaled correctly
        assertEq(decodedData.fromAmount, SCALED_AMOUNT, "From amount should be scaled to the new amount");
        assertEq(decodedData.toAmount, EXPECTED_SCALED_TO_AMOUNT, "To amount should be scaled proportionally (2x)");
        assertEq(decodedData.quotedAmount, EXPECTED_SCALED_QUOTED_AMOUNT, "Quoted amount should be scaled proportionally (2x)");

        // Check that the executor and other parameters stayed the same
        assertEq(decodedExecutor, EXECUTOR, "Executor address should not change");
        assertEq(decodedPartnerAndFee, PARTNER_AND_FEE, "Partner and fee should not change");
        assertEq(keccak256(decodedPermit), keccak256(PERMIT), "Permit should not change");
        assertEq(keccak256(decodedExecutorData), keccak256(EXECUTOR_DATA), "Executor data should not change");

        // Check that the token addresses stayed the same
        assertEq(address(decodedData.srcToken), TOKEN_SRC, "Source token should not change");
        assertEq(address(decodedData.destToken), TOKEN_DEST, "Destination token should not change");
        assertEq(decodedData.beneficiary, payable(BENEFICIARY), "Beneficiary should not change");
        assertEq(decodedData.metadata, bytes32(0), "Metadata should not change");
        
    }

    function test_swapExactAmountInOnUniswapV2() public {
        // Create a sample UniswapV2Data struct
        IAugustusV6.UniswapV2Data memory data = IAugustusV6.UniswapV2Data({
            srcToken: IERC20(TOKEN_SRC),
            destToken: IERC20(TOKEN_DEST),
            fromAmount: ORIGINAL_AMOUNT,
            toAmount: EXPECTED_TO_AMOUNT,
            quotedAmount: EXPECTED_QUOTED_AMOUNT,
            metadata: bytes32(0),
            beneficiary: payable(BENEFICIARY),
            pools: bytes("uniswapRouteData")
        });

        // Create the original calldata
        bytes memory rawCallData = abi.encodeWithSelector(
            IAugustusV6.swapExactAmountInOnUniswapV2.selector,
            EXECUTOR,
            data,
            PARTNER_AND_FEE,
            PERMIT
        );

        // Scale the amount by 2x
        bytes memory scaledCallData = helper.exposedParaswapScaling(rawCallData, SCALED_AMOUNT);

        // Decode the scaled calldata and verify the amounts
        bytes memory callDataWithoutSelector = new bytes(scaledCallData.length - 4);
        for (uint i = 0; i < callDataWithoutSelector.length; i++) {
            callDataWithoutSelector[i] = scaledCallData[i + 4];
        }
        
        (
            address decodedExecutor,
            IAugustusV6.UniswapV2Data memory decodedData,
            uint256 decodedPartnerAndFee,
            bytes memory decodedPermit
        ) = abi.decode(
            callDataWithoutSelector,
            (address, IAugustusV6.UniswapV2Data, uint256, bytes)
        );

        // Check that the amounts have been scaled correctly
        assertEq(decodedData.fromAmount, SCALED_AMOUNT, "From amount should be scaled to the new amount");
        assertEq(decodedData.toAmount, EXPECTED_SCALED_TO_AMOUNT, "To amount should be scaled proportionally (2x)");
        assertEq(decodedData.quotedAmount, EXPECTED_SCALED_QUOTED_AMOUNT, "Quoted amount should be scaled proportionally (2x)");

        // Check that the executor and other parameters stayed the same
        assertEq(decodedExecutor, EXECUTOR, "Executor address should not change");
        assertEq(decodedPartnerAndFee, PARTNER_AND_FEE, "Partner and fee should not change");
        assertEq(keccak256(decodedPermit), keccak256(PERMIT), "Permit should not change");

        // Check that the token addresses and other fields stayed the same
        assertEq(address(decodedData.srcToken), TOKEN_SRC, "Source token should not change");
        assertEq(address(decodedData.destToken), TOKEN_DEST, "Destination token should not change");
        assertEq(decodedData.beneficiary, payable(BENEFICIARY), "Beneficiary should not change");
        assertEq(decodedData.metadata, bytes32(0), "Metadata should not change");
        assertEq(keccak256(decodedData.pools), keccak256(bytes("uniswapRouteData")), "Pools data should not change");
    }

    function test_swapExactAmountInOnUniswapV3() public {
        // Create a sample UniswapV3Data struct
        IAugustusV6.UniswapV3Data memory data = IAugustusV6.UniswapV3Data({
            srcToken: IERC20(TOKEN_SRC),
            destToken: IERC20(TOKEN_DEST),
            fromAmount: ORIGINAL_AMOUNT,
            toAmount: EXPECTED_TO_AMOUNT,
            quotedAmount: EXPECTED_QUOTED_AMOUNT,
            metadata: bytes32(0),
            beneficiary: payable(BENEFICIARY),
            pools: bytes("uniswapV3RouteData")
        });

        // Create the original calldata
        bytes memory rawCallData = abi.encodeWithSelector(
            IAugustusV6.swapExactAmountInOnUniswapV3.selector,
            EXECUTOR,
            data,
            PARTNER_AND_FEE,
            PERMIT
        );

        // Scale the amount by 2x
        bytes memory scaledCallData = helper.exposedParaswapScaling(rawCallData, SCALED_AMOUNT);

        // Decode the scaled calldata and verify the amounts
        bytes memory callDataWithoutSelector = new bytes(scaledCallData.length - 4);
        for (uint i = 0; i < callDataWithoutSelector.length; i++) {
            callDataWithoutSelector[i] = scaledCallData[i + 4];
        }
        
        (
            address decodedExecutor,
            IAugustusV6.UniswapV3Data memory decodedData,
            uint256 decodedPartnerAndFee,
            bytes memory decodedPermit
        ) = abi.decode(
            callDataWithoutSelector,
            (address, IAugustusV6.UniswapV3Data, uint256, bytes)
        );

        // Check that the amounts have been scaled correctly
        assertEq(decodedData.fromAmount, SCALED_AMOUNT, "From amount should be scaled to the new amount");
        assertEq(decodedData.toAmount, EXPECTED_SCALED_TO_AMOUNT, "To amount should be scaled proportionally (2x)");
        assertEq(decodedData.quotedAmount, EXPECTED_SCALED_QUOTED_AMOUNT, "Quoted amount should be scaled proportionally (2x)");

        // Check that the executor and other parameters stayed the same
        assertEq(decodedExecutor, EXECUTOR, "Executor address should not change");
        assertEq(decodedPartnerAndFee, PARTNER_AND_FEE, "Partner and fee should not change");
        assertEq(keccak256(decodedPermit), keccak256(PERMIT), "Permit should not change");

        // Check that the token addresses and other fields stayed the same
        assertEq(address(decodedData.srcToken), TOKEN_SRC, "Source token should not change");
        assertEq(address(decodedData.destToken), TOKEN_DEST, "Destination token should not change");
        assertEq(decodedData.beneficiary, payable(BENEFICIARY), "Beneficiary should not change");
        assertEq(decodedData.metadata, bytes32(0), "Metadata should not change");
        assertEq(keccak256(decodedData.pools), keccak256(bytes("uniswapV3RouteData")), "Pools data should not change");
    }

    function test_swapExactAmountInOnBalancerV2() public {
        // Create a sample BalancerV2Data struct
        IAugustusV6.BalancerV2Data memory data = IAugustusV6.BalancerV2Data({
            fromAmount: ORIGINAL_AMOUNT,
            toAmount: EXPECTED_TO_AMOUNT,
            quotedAmount: EXPECTED_QUOTED_AMOUNT,
            metadata: bytes32(0),
            beneficiaryAndApproveFlag: 1234567890
        });

        // Other parameters
        bytes memory extraData = "balancerExtraData";

        // Create the original calldata
        bytes memory rawCallData = abi.encodeWithSelector(
            IAugustusV6.swapExactAmountInOnBalancerV2.selector,
            EXECUTOR,
            data,
            PARTNER_AND_FEE,
            PERMIT,
            extraData
        );

        // Scale the amount by 2x
        bytes memory scaledCallData = helper.exposedParaswapScaling(rawCallData, SCALED_AMOUNT);

        // Decode the scaled calldata and verify the amounts
        bytes memory callDataWithoutSelector = new bytes(scaledCallData.length - 4);
        for (uint i = 0; i < callDataWithoutSelector.length; i++) {
            callDataWithoutSelector[i] = scaledCallData[i + 4];
        }
        
        (
            address decodedExecutor,
            IAugustusV6.BalancerV2Data memory decodedData,
            uint256 decodedPartnerAndFee,
            bytes memory decodedPermit,
            bytes memory decodedExtraData
        ) = abi.decode(
            callDataWithoutSelector,
            (address, IAugustusV6.BalancerV2Data, uint256, bytes, bytes)
        );

        // Check that the amounts have been scaled correctly
        assertEq(decodedData.fromAmount, SCALED_AMOUNT, "From amount should be scaled to the new amount");
        assertEq(decodedData.toAmount, EXPECTED_SCALED_TO_AMOUNT, "To amount should be scaled proportionally (2x)");
        assertEq(decodedData.quotedAmount, EXPECTED_SCALED_QUOTED_AMOUNT, "Quoted amount should be scaled proportionally (2x)");

        // Check that the executor and other parameters stayed the same
        assertEq(decodedExecutor, EXECUTOR, "Executor address should not change");
        assertEq(decodedPartnerAndFee, PARTNER_AND_FEE, "Partner and fee should not change");
        assertEq(keccak256(decodedPermit), keccak256(PERMIT), "Permit should not change");
        assertEq(keccak256(decodedExtraData), keccak256(extraData), "Extra data should not change");

        // Check that other fields stayed the same
        assertEq(decodedData.metadata, bytes32(0), "Metadata should not change");
        assertEq(decodedData.beneficiaryAndApproveFlag, 1234567890, "Beneficiary flag should not change");
    }

    function test_swapExactAmountInOnCurveV1() public {
        // Create a sample CurveV1Data struct
        IAugustusV6.CurveV1Data memory data = IAugustusV6.CurveV1Data({
            curveData: 12345,
            curveAssets: 67890,
            srcToken: IERC20(TOKEN_SRC),
            destToken: IERC20(TOKEN_DEST),
            fromAmount: ORIGINAL_AMOUNT,
            toAmount: EXPECTED_TO_AMOUNT,
            quotedAmount: EXPECTED_QUOTED_AMOUNT,
            metadata: bytes32(0),
            beneficiary: payable(BENEFICIARY)
        });

        // Create the original calldata
        bytes memory rawCallData = abi.encodeWithSelector(
            IAugustusV6.swapExactAmountInOnCurveV1.selector,
            EXECUTOR,
            data,
            PARTNER_AND_FEE,
            PERMIT
        );

        // Scale the amount by 2x
        bytes memory scaledCallData = helper.exposedParaswapScaling(rawCallData, SCALED_AMOUNT);

        // Decode the scaled calldata and verify the amounts
        bytes memory callDataWithoutSelector = new bytes(scaledCallData.length - 4);
        for (uint i = 0; i < callDataWithoutSelector.length; i++) {
            callDataWithoutSelector[i] = scaledCallData[i + 4];
        }
        
        (
            address decodedExecutor,
            IAugustusV6.CurveV1Data memory decodedData,
            uint256 decodedPartnerAndFee,
            bytes memory decodedPermit
        ) = abi.decode(
            callDataWithoutSelector,
            (address, IAugustusV6.CurveV1Data, uint256, bytes)
        );

        // Check that the amounts have been scaled correctly
        assertEq(decodedData.fromAmount, SCALED_AMOUNT, "From amount should be scaled to the new amount");
        assertEq(decodedData.toAmount, EXPECTED_SCALED_TO_AMOUNT, "To amount should be scaled proportionally (2x)");
        assertEq(decodedData.quotedAmount, EXPECTED_SCALED_QUOTED_AMOUNT, "Quoted amount should be scaled proportionally (2x)");

        // Check that the executor and other parameters stayed the same
        assertEq(decodedExecutor, EXECUTOR, "Executor address should not change");
        assertEq(decodedPartnerAndFee, PARTNER_AND_FEE, "Partner and fee should not change");
        assertEq(keccak256(decodedPermit), keccak256(PERMIT), "Permit should not change");

        // Check that other fields stayed the same
        assertEq(address(decodedData.srcToken), TOKEN_SRC, "Source token should not change");
        assertEq(address(decodedData.destToken), TOKEN_DEST, "Destination token should not change");
        assertEq(decodedData.curveData, 12345, "Curve data should not change");
        assertEq(decodedData.curveAssets, 67890, "Curve assets should not change");
        assertEq(decodedData.beneficiary, payable(BENEFICIARY), "Beneficiary should not change");
        assertEq(decodedData.metadata, bytes32(0), "Metadata should not change");
    }

    function test_swapExactAmountInOnCurveV2() public {
        // Create a sample CurveV2Data struct
        IAugustusV6.CurveV2Data memory data = IAugustusV6.CurveV2Data({
            curveData: 12345,
            i: 0,
            j: 1,
            poolAddress: address(0x1234567890123456789012345678901234567890),
            srcToken: IERC20(TOKEN_SRC),
            destToken: IERC20(TOKEN_DEST),
            fromAmount: ORIGINAL_AMOUNT,
            toAmount: EXPECTED_TO_AMOUNT,
            quotedAmount: EXPECTED_QUOTED_AMOUNT,
            metadata: bytes32(0),
            beneficiary: payable(BENEFICIARY)
        });

        // Create the original calldata
        bytes memory rawCallData = abi.encodeWithSelector(
            IAugustusV6.swapExactAmountInOnCurveV2.selector,
            EXECUTOR,
            data,
            PARTNER_AND_FEE,
            PERMIT
        );

        // Scale the amount by 2x
        bytes memory scaledCallData = helper.exposedParaswapScaling(rawCallData, SCALED_AMOUNT);

        // Decode the scaled calldata and verify the amounts
        bytes memory callDataWithoutSelector = new bytes(scaledCallData.length - 4);
        for (uint i = 0; i < callDataWithoutSelector.length; i++) {
            callDataWithoutSelector[i] = scaledCallData[i + 4];
        }
        
        (
            address decodedExecutor,
            IAugustusV6.CurveV2Data memory decodedData,
            uint256 decodedPartnerAndFee,
            bytes memory decodedPermit
        ) = abi.decode(
            callDataWithoutSelector,
            (address, IAugustusV6.CurveV2Data, uint256, bytes)
        );

        // Check that the amounts have been scaled correctly
        assertEq(decodedData.fromAmount, SCALED_AMOUNT, "From amount should be scaled to the new amount");
        assertEq(decodedData.toAmount, EXPECTED_SCALED_TO_AMOUNT, "To amount should be scaled proportionally (2x)");
        assertEq(decodedData.quotedAmount, EXPECTED_SCALED_QUOTED_AMOUNT, "Quoted amount should be scaled proportionally (2x)");

        // Check that the executor and other parameters stayed the same
        assertEq(decodedExecutor, EXECUTOR, "Executor address should not change");
        assertEq(decodedPartnerAndFee, PARTNER_AND_FEE, "Partner and fee should not change");
        assertEq(keccak256(decodedPermit), keccak256(PERMIT), "Permit should not change");

        // Check that other fields stayed the same
        assertEq(address(decodedData.srcToken), TOKEN_SRC, "Source token should not change");
        assertEq(address(decodedData.destToken), TOKEN_DEST, "Destination token should not change");
        assertEq(decodedData.curveData, 12345, "Curve data should not change");
        assertEq(decodedData.i, 0, "i value should not change");
        assertEq(decodedData.j, 1, "j value should not change");
        assertEq(decodedData.poolAddress, address(0x1234567890123456789012345678901234567890), "Pool address should not change");
        assertEq(decodedData.beneficiary, payable(BENEFICIARY), "Beneficiary should not change");
        assertEq(decodedData.metadata, bytes32(0), "Metadata should not change");
    }

    function test_swapOnAugustusRFQTryBatchFill() public {
        // Create a sample AugustusRFQData struct
        IAugustusV6.AugustusRFQData memory data = IAugustusV6.AugustusRFQData({
            fromAmount: ORIGINAL_AMOUNT,
            toAmount: EXPECTED_TO_AMOUNT,
            wrapApproveDirection: 1,
            metadata: bytes32(0),
            beneficiary: payable(BENEFICIARY)
        });

        // Create a sample order
        IAugustusV6.Order memory order = IAugustusV6.Order({
            nonceAndMeta: 12345,
            expiry: 67890,
            makerAsset: TOKEN_SRC,
            takerAsset: TOKEN_DEST,
            maker: address(0x2),
            taker: address(0x3),
            makerAmount: 5000,
            takerAmount: 3000
        });

        // Create order info array
        IAugustusV6.OrderInfo[] memory orders = new IAugustusV6.OrderInfo[](1);
        orders[0] = IAugustusV6.OrderInfo({
            order: order,
            signature: bytes("signature"),
            takerTokenFillAmount: 3000,
            permitTakerAsset: bytes("permit1"),
            permitMakerAsset: bytes("permit2")
        });

        // Create the original calldata
        bytes memory rawCallData = abi.encodeWithSelector(
            IAugustusV6.swapOnAugustusRFQTryBatchFill.selector,
            EXECUTOR,
            data,
            orders,
            PERMIT
        );

        // Scale the amount by 2x
        bytes memory scaledCallData = helper.exposedParaswapScaling(rawCallData, SCALED_AMOUNT);

        // Decode the scaled calldata and verify the amounts
        bytes memory callDataWithoutSelector = new bytes(scaledCallData.length - 4);
        for (uint i = 0; i < callDataWithoutSelector.length; i++) {
            callDataWithoutSelector[i] = scaledCallData[i + 4];
        }
        
        (
            address decodedExecutor,
            IAugustusV6.AugustusRFQData memory decodedData,
            IAugustusV6.OrderInfo[] memory decodedOrders,
            bytes memory decodedPermit
        ) = abi.decode(
            callDataWithoutSelector,
            (address, IAugustusV6.AugustusRFQData, IAugustusV6.OrderInfo[], bytes)
        );

        // Check that the amounts have been scaled correctly
        assertEq(decodedData.fromAmount, SCALED_AMOUNT, "From amount should be scaled to the new amount");
        assertEq(decodedData.toAmount, EXPECTED_SCALED_TO_AMOUNT, "To amount should be scaled proportionally (2x)");

        // Check that the executor and other parameters stayed the same
        assertEq(decodedExecutor, EXECUTOR, "Executor address should not change");
        assertEq(keccak256(decodedPermit), keccak256(PERMIT), "Permit should not change");

        // Check that other fields stayed the same
        assertEq(decodedData.wrapApproveDirection, 1, "Wrap direction should not change");
        assertEq(decodedData.beneficiary, payable(BENEFICIARY), "Beneficiary should not change");
        assertEq(decodedData.metadata, bytes32(0), "Metadata should not change");
        
        // Check that orders data is preserved
        assertEq(decodedOrders.length, 1, "Should have 1 order");
        assertEq(decodedOrders[0].order.nonceAndMeta, 12345, "Order nonce should not change");
        assertEq(decodedOrders[0].order.expiry, 67890, "Order expiry should not change");
    }

    function test_swapExactAmountInOutOnMakerPSM() public {
        // Create a sample MakerPSMData struct
        IAugustusV6.MakerPSMData memory data = IAugustusV6.MakerPSMData({
            srcToken: IERC20(TOKEN_SRC),
            destToken: IERC20(TOKEN_DEST),
            fromAmount: ORIGINAL_AMOUNT,
            toAmount: EXPECTED_TO_AMOUNT,
            toll: 10,
            to18ConversionFactor: 1e18,
            exchange: address(0x4),
            gemJoinAddress: address(0x5),
            metadata: bytes32(0),
            beneficiaryDirectionApproveFlag: 12345
        });

        // Create the original calldata
        bytes memory rawCallData = abi.encodeWithSelector(
            IAugustusV6.swapExactAmountInOutOnMakerPSM.selector,
            EXECUTOR,
            data,
            PERMIT
        );

        // Scale the amount by 2x
        bytes memory scaledCallData = helper.exposedParaswapScaling(rawCallData, SCALED_AMOUNT);

        // Decode the scaled calldata and verify the amounts
        bytes memory callDataWithoutSelector = new bytes(scaledCallData.length - 4);
        for (uint i = 0; i < callDataWithoutSelector.length; i++) {
            callDataWithoutSelector[i] = scaledCallData[i + 4];
        }
        
        (
            address decodedExecutor,
            IAugustusV6.MakerPSMData memory decodedData,
            bytes memory decodedPermit
        ) = abi.decode(
            callDataWithoutSelector,
            (address, IAugustusV6.MakerPSMData, bytes)
        );

        // Check that the amounts have been scaled correctly
        assertEq(decodedData.fromAmount, SCALED_AMOUNT, "From amount should be scaled to the new amount");
        assertEq(decodedData.toAmount, EXPECTED_SCALED_TO_AMOUNT, "To amount should be scaled proportionally (2x)");

        // Check that the executor and other parameters stayed the same
        assertEq(decodedExecutor, EXECUTOR, "Executor address should not change");
        assertEq(keccak256(decodedPermit), keccak256(PERMIT), "Permit should not change");

        // Check that other fields stayed the same
        assertEq(address(decodedData.srcToken), TOKEN_SRC, "Source token should not change");
        assertEq(address(decodedData.destToken), TOKEN_DEST, "Destination token should not change");
        assertEq(decodedData.toll, 10, "Toll should not change");
        assertEq(decodedData.to18ConversionFactor, 1e18, "Conversion factor should not change");
        assertEq(decodedData.exchange, address(0x4), "Exchange should not change");
        assertEq(decodedData.gemJoinAddress, address(0x5), "GemJoin address should not change");
        assertEq(decodedData.metadata, bytes32(0), "Metadata should not change");
        assertEq(decodedData.beneficiaryDirectionApproveFlag, 12345, "Beneficiary flag should not change");
    }

    function test_InvalidSelector() public {
        // Test that the scaling function reverts for an invalid selector
        bytes memory invalidCallData = abi.encodeWithSelector(
            bytes4(keccak256("invalidFunction()")),
            address(0x1),
            100,
            200
        );
        
        vm.expectRevert("ParaswapScaleHelper: Unsupported swap selector");
        helper.exposedParaswapScaling(invalidCallData, 1000);
    }
} 