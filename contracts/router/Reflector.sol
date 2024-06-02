// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../interfaces/IPAllActionV3.sol";
import "../interfaces/IPReflector.sol";
import "../core/libraries/TokenHelper.sol";

contract Reflector is TokenHelper, IPReflector {
    using SafeERC20 for IERC20;

    mapping(address => bool) internal approved;
    address internal constant ROUTER = 0x888888888889758F76e7103c6CbF23ABbF58F946;

    receive() external payable {}

    function reflect(bytes calldata inputData) external returns (bytes memory result) {
        (uint256 value, bytes memory newCalldata) = _getNewCalldata(inputData);
        bool success;

        (success, result) = ROUTER.call{value: value}(newCalldata);
        if (!success) {
            assembly {
                // We use Yul's revert() to bubble up errors from the target contract.
                revert(add(32, result), mload(result))
            }
        }
    }

    function _getNewCalldata(bytes calldata inputData) internal returns (uint256 value, bytes memory newCalldata) {
        bytes4 selector = bytes4(inputData[:4]);
        bytes calldata data = inputData[4:];

        if (selector == IPActionAddRemoveLiqV3.addLiquiditySingleToken.selector) {
            (
                address v1,
                address v2,
                uint256 v3,
                ApproxParams memory v4,
                TokenInput memory v5,
                LimitOrderData memory v6
            ) = abi.decode(data, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

            value = _scaleTokenInputAndGetValue(v5);
            newCalldata = abi.encodeWithSelector(selector, v1, v2, v3, v4, v5, v6);
        } else if (selector == IPActionAddRemoveLiqV3.addLiquiditySingleTokenKeepYt.selector) {
            (address v1, address v2, uint256 v3, uint256 v4, TokenInput memory v5) = abi.decode(
                data,
                (address, address, uint256, uint256, TokenInput)
            );

            value = _scaleTokenInputAndGetValue(v5);
            newCalldata = abi.encodeWithSelector(selector, v1, v2, v3, v4, v5);
        } else {
            revert("UNSUPPORTED_SELECTOR");
        }
    }

    function _scaleTokenInputAndGetValue(TokenInput memory inp) internal returns (uint256 ethValue) {
        require(inp.swapData.swapType == SwapType.NONE, "SWAP_NOT_ALLOWED"); // the exit call should already swap

        inp.netTokenIn = _selfBalance(inp.tokenIn);

        if (inp.tokenIn == NATIVE) {
            ethValue = inp.netTokenIn;
        } else if (!approved[inp.tokenIn]) {
            IERC20(inp.tokenIn).forceApprove(ROUTER, type(uint256).max);
            approved[inp.tokenIn] = true;
        }
    }
}
