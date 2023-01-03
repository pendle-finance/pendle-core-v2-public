// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./base/PendleAuraBalancerStableLPSY.sol";
import "../../StEthHelper.sol";
import "./base/ComposableStable/ComposableStablePreview.sol";

contract PendleAuraCbEthWstEthSY is PendleAuraBalancerStableLPSY, StEthHelper {
    address public constant CBETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;

    uint256 internal constant AURA_PID = 37;
    address internal constant LP = 0x4EdcB2B46377530Bc18BB4D2c7Fe46a992c73e10;

    uint256 public constant BPT_INDEX = 0;
    bool public constant NO_TOKENS_EXEMPT = true;
    bool public constant ALL_TOKENS_EXEMPT = false;

    constructor(
        string memory _name,
        string memory _symbol,
        ComposableStablePreview _previewHelper
    ) PendleAuraBalancerStableLPSY(_name, _symbol, LP, AURA_PID, _previewHelper) {}

    function _deposit(address tokenIn, uint256 amount)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == NATIVE || tokenIn == WETH || tokenIn == STETH) {
            uint256 amountWstETH = _depositWstETH(tokenIn, amount);
            amountSharesOut = super._deposit(WSTETH, amountWstETH);
        } else {
            amountSharesOut = super._deposit(tokenIn, amount);
        }
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        if (tokenOut == STETH) {
            uint256 amountWstETH = super._redeem(address(this), WSTETH, amountSharesToRedeem);
            amountTokenOut = _redeemWstETH(receiver, amountWstETH);
        } else {
            amountTokenOut = super._redeem(receiver, tokenOut, amountSharesToRedeem);
        }
    }

    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == NATIVE || tokenIn == WETH || tokenIn == STETH) {
            uint256 amountWstETH = _previewDepositWstETH(tokenIn, amountTokenToDeposit);
            amountSharesOut = super._previewDeposit(WSTETH, amountWstETH);
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
        if (tokenOut == STETH) {
            uint256 amountWstETH = super._previewRedeem(WSTETH, amountSharesToRedeem);
            amountTokenOut = _previewRedeemWstETH(amountWstETH);
        } else {
            amountTokenOut = super._previewRedeem(tokenOut, amountSharesToRedeem);
        }
    }

    function _getImmutablePoolData() internal view virtual override returns (bytes memory ret) {
        ComposableStablePreview.ImmutableData memory res;
        res.poolTokens = _getPoolTokenAddresses();
        res.rateProviders = _getRateProviders();
        res.rawScalingFactors = _getRawScalingFactors();
        res.isExemptFromYieldProtocolFee = _getExemption();
        res.LP = LP;
        res.noTokensExempt = NO_TOKENS_EXEMPT;
        res.allTokensExempt = ALL_TOKENS_EXEMPT;
        res.bptIndex = BPT_INDEX;
        res.totalTokens = res.poolTokens.length;

        return abi.encode(res);
    }

    function _getPoolTokenAddresses()
        internal
        view
        virtual
        override
        returns (address[] memory res)
    {
        res = new address[](3);
        res[0] = LP;
        res[1] = WSTETH;
        res[2] = CBETH;
    }

    function _getBPTIndex() internal view virtual override returns (uint256) {
        return BPT_INDEX;
    }

    function _getRateProviders() internal view virtual returns (address[] memory res) {
        res = new address[](3);
        res[0] = 0x0000000000000000000000000000000000000000;
        res[1] = 0x72D07D7DcA67b8A406aD1Ec34ce969c90bFEE768;
        res[2] = 0x7311E4BB8a72e7B300c5B8BDE4de6CdaA822a5b1;
    }

    function _getRawScalingFactors() internal view virtual returns (uint256[] memory res) {
        res = new uint256[](3);
        res[0] = res[1] = res[2] = 1e18;
    }

    function _getExemption() internal view virtual returns (bool[] memory res) {
        res = new bool[](3);
        res[0] = res[1] = res[2] = false;
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](6);
        res[0] = WSTETH;
        res[1] = STETH;
        res[2] = NATIVE;
        res[3] = WETH;
        // All 4 converted to WSTETH
        res[4] = CBETH;
        res[5] = LP;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](4);
        res[0] = WSTETH;
        res[1] = STETH;
        //
        res[2] = CBETH;
        res[3] = LP;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return (token == WSTETH ||
            token == STETH ||
            token == NATIVE ||
            token == WETH ||
            token == CBETH ||
            token == LP);
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return (token == WSTETH || token == STETH || token == CBETH || token == LP);
    }
}
