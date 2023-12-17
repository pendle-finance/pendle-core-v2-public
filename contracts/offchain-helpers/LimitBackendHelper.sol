// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "../interfaces/IPLimitRouter.sol";
import "../core/libraries/TokenHelper.sol";
import "../interfaces/IStandardizedYield.sol";
import "../interfaces/IWETH.sol";
import "../core/libraries/Errors.sol";
import "./BytesLib.sol";

contract LimitBackendHelper is TokenHelper {
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
    function mintSyFromTokens(
        address YT,
        address[] calldata makers,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external returns (uint256[] memory minted) {
        uint256 length = makers.length;

        address SY = IPYieldToken(YT).SY();
        minted = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            (, bytes memory result) = original.delegatecall(
                abi.encodeWithSignature(
                    "mintSyFromTokenRevert(address,address,address,uint256)",
                    makers[i],
                    SY,
                    tokens[i],
                    amounts[i]
                )
            );
            minted[i] = parseMinted(result);
        }
    }

    function parseMinted(bytes memory result) internal pure returns (uint256 minted) {
        if (result.length < 4) return type(uint256).max;

        bytes4 top = bytes4(BytesLib.slice(result, 0, 4));
        if (top == bytes4(0x1934afc8)) {
            // selector of SimulationResults
            (, bytes memory beta) = abi.decode(BytesLib.slice(result, 4, result.length - 4), (bool, bytes));
            minted = abi.decode(beta, (uint256));
        } else {
            minted = type(uint256).max;
        }
    }

    function mintSyFromTokenRevert(
        address maker,
        address SY,
        address token,
        uint256 makingAmount
    ) public returns (uint256) {
        _transferIn(token, maker, makingAmount);
        if (token == WNATIVE && !IStandardizedYield(SY).isValidTokenIn(WNATIVE)) {
            _wrap_unwrap_ETH(WNATIVE, NATIVE, makingAmount);
            token = NATIVE;
        }
        _safeApproveInf(token, SY);
        uint256 minted = IStandardizedYield(SY).deposit{value: token == NATIVE ? makingAmount : 0}(
            address(this),
            token,
            makingAmount,
            0
        );
        revert Errors.SimulationResults(true, abi.encode(minted));
    }
}
