// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./base/PendleAuraBalancerStableLPSYV2.sol";
import "./base/ComposableStable/ComposableStablePreview.sol";

contract PendleAuraWethVethSY is PendleAuraBalancerStableLPSYV2 {
    address internal constant VETH = 0x4Bc3263Eb5bb2Ef7Ad9aB6FB68be80E43b43801F;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 internal constant AURA_PID = 128;
    address internal constant LP = 0x156C02f3f7fEf64a3A9D80CCF7085f23ccE91D76;

    bool internal constant NO_TOKENS_EXEMPT = true;
    bool internal constant ALL_TOKENS_EXEMPT = false;

    constructor(
        string memory _name,
        string memory _symbol,
        ComposableStablePreview _composablePreviewHelper
    )
        PendleAuraBalancerStableLPSYV2(_name, _symbol, LP, AURA_PID, _composablePreviewHelper)
    //solhint-disable-next-line
    {

    }

    function _deposit(address tokenIn, uint256 amount)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == NATIVE) {
            IWETH(WETH).deposit{ value: amount }();
            amountSharesOut = super._deposit(WETH, amount);
        } else {
            amountSharesOut = super._deposit(tokenIn, amount);
        }
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256) {
        if (tokenOut == NATIVE) {
            uint256 amountTokenOut = super._redeem(address(this), WETH, amountSharesToRedeem);
            IWETH(WETH).withdraw(amountTokenOut);
            _transferOut(NATIVE, receiver, amountTokenOut);
            return amountTokenOut;
        } else {
            return super._redeem(receiver, tokenOut, amountSharesToRedeem);
        }
    }

    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == NATIVE) {
            amountSharesOut = super._previewDeposit(WETH, amountTokenToDeposit);
        } else {
            amountSharesOut = super._previewDeposit(tokenIn, amountTokenToDeposit);
        }
    }

    function _previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        view
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == NATIVE) {
            amountTokenOut = super._previewRedeem(WETH, amountSharesToRedeem);
        } else {
            amountTokenOut = super._previewRedeem(tokenOut, amountSharesToRedeem);
        }
    }

    function _getImmutablePoolData() internal pure override returns (bytes memory ret) {
        ComposableStablePreview.ImmutableData memory res;
        res.poolTokens = _getPoolTokenAddresses();
        res.rateProviders = _getRateProviders();
        res.rawScalingFactors = _getRawScalingFactors();
        res.isExemptFromYieldProtocolFee = _getExemption();
        res.LP = LP;
        res.noTokensExempt = NO_TOKENS_EXEMPT;
        res.allTokensExempt = ALL_TOKENS_EXEMPT;
        res.bptIndex = _getBPTIndex();
        res.totalTokens = res.poolTokens.length;

        return abi.encode(res);
    }

    //  --------------------------------- POOL CONSTANTS ---------------------------------
    function _getPoolTokenAddresses() internal pure override returns (address[] memory res) {
        res = new address[](3);
        res[0] = LP;
        res[1] = VETH;
        res[2] = WETH;
    }

    function _getBPTIndex() internal pure override returns (uint256) {
        return 0;
    }

    function _getRateProviders() internal pure returns (address[] memory res) {
        res = new address[](3);
        res[0] = 0x0000000000000000000000000000000000000000;
        res[1] = 0x12589A727aeFAc3fbE5025F890f1CB97c269BEc2;
        res[2] = 0x0000000000000000000000000000000000000000;
    }

    function _getRawScalingFactors() internal pure returns (uint256[] memory res) {
        res = new uint256[](3);
        res[0] = res[1] = res[2] = 1e18;
    }

    function _getExemption() internal pure returns (bool[] memory res) {
        res = new bool[](3);
        res[0] = res[1] = res[2] = false;
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](4);
        res[0] = LP;
        res[1] = WETH;
        res[2] = VETH;
        res[3] = NATIVE;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        return getTokensIn();
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return (token == LP || token == WETH || token == VETH || token == NATIVE);
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return isValidTokenIn(token);
    }
}