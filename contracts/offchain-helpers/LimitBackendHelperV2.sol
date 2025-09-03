// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "../interfaces/IPLimitRouter.sol";
import "../core/libraries/TokenHelper.sol";
import "../interfaces/IStandardizedYield.sol";
import "../interfaces/IWETH.sol";
import "../core/libraries/Errors.sol";
import "./BytesLib.sol";

contract LimitBackendHelperV2 is TokenHelper {
    address private immutable WNATIVE;
    address private immutable original;

    constructor(address _WNATIVE) {
        WNATIVE = _WNATIVE;
        original = address(this);
    }

    /// @notice vanilla read
    function readSingleToken(
        address token,
        address[] calldata owners,
        address spender
    ) public view returns (uint256[] memory balances, uint256[] memory allowances) {
        balances = new uint256[](owners.length);
        allowances = new uint256[](owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            balances[i] = IERC20(token).balanceOf(owners[i]);
            allowances[i] = IERC20(token).allowance(owners[i], spender);
        }
    }

    /// @notice auto return balances and allowances the input tokens of the orders, based on type
    function readMultiTokens(
        address[] calldata tokens,
        address[] calldata owners,
        address spender
    ) public view returns (uint256[] memory balances, uint256[] memory allowances) {
        require(tokens.length == owners.length, "Length mismatch");
        balances = new uint256[](owners.length);
        allowances = new uint256[](owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            balances[i] = IERC20(tokens[i]).balanceOf(owners[i]);
            allowances[i] = IERC20(tokens[i]).allowance(owners[i], spender);
        }
    }

    /// @notice to be delegatecall from LimitRouter
    function mintSyFromTokensV2(
        address YT,
        address[] calldata makers,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external returns (uint256[] memory minted, bytes[] memory error) {
        uint256 length = makers.length;

        address SY = IPYieldToken(YT).SY();
        minted = new uint256[](length);
        error = new bytes[](length);

        for (uint256 i = 0; i < length; i++) {
            (, bytes memory result) = original.delegatecall(
                abi.encodeCall(this.mintSyFromTokenRevert, (makers[i], SY, tokens[i], amounts[i]))
            );
            (minted[i], error[i]) = parseMinted(result);
        }
    }

    function parseMinted(bytes memory result) internal pure returns (uint256 minted, bytes memory error) {
        assert(result.length >= 4 && bytes4(result) == Errors.SimulationResults.selector);
        (bool success, bytes memory data) = abi.decode(BytesLib.slice(result, 4, result.length - 4), (bool, bytes));

        if (success) {
            minted = abi.decode(data, (uint256));
        } else {
            minted = type(uint256).max;
            error = data;
        }
    }

    function mintSyFromTokenRevert(address maker, address SY, address token, uint256 makingAmount) public {
        _transferIn(token, maker, makingAmount);
        if (token == WNATIVE && !IStandardizedYield(SY).isValidTokenIn(WNATIVE)) {
            _wrap_unwrap_ETH(WNATIVE, NATIVE, makingAmount);
            token = NATIVE;
        }
        _safeApproveInf(token, SY);
        (bool success, bytes memory result) = SY.call{value: token == NATIVE ? makingAmount : 0}(
            abi.encodeCall(IStandardizedYield.deposit, (address(this), token, makingAmount, 0))
        );
        revert Errors.SimulationResults(success, result);
    }
}
