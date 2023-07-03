// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./base/PendleAuraBalancerStableLPSYV2.sol";
import "./base/ComposableStable/ComposableStablePreview.sol";

contract PendleAuraWstethAnkreth is PendleAuraBalancerStableLPSYV2 {
    uint256 internal constant AURA_PID = 125;
    address internal constant LP = 0xdfE6e7e18f6Cc65FA13C8D8966013d4FdA74b6ba;
    address internal constant ANKRETH = 0xE95A203B1a91a908F9B9CE46459d101078c2c3cb;
    address internal constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

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

    function _deposit(
        address tokenIn,
        uint256 amount
    ) internal override returns (uint256 amountSharesOut) {
        amountSharesOut = super._deposit(tokenIn, amount);
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal override returns (uint256 amountTokenOut) {
        return super._redeem(receiver, tokenOut, amountSharesToRedeem);
    }

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view override returns (uint256) {
        return super._previewDeposit(tokenIn, amountTokenToDeposit);
    }

    function _previewRedeem(
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal view override returns (uint256) {
        return super._previewRedeem(tokenOut, amountSharesToRedeem);
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
        res[0] = WSTETH;
        res[1] = LP;
        res[2] = ANKRETH;
    }

    function _getBPTIndex() internal pure override returns (uint256) {
        return 1;
    }

    function _getRateProviders() internal pure returns (address[] memory res) {
        res = new address[](3);
        res[0] = 0x72D07D7DcA67b8A406aD1Ec34ce969c90bFEE768;
        res[1] = 0x0000000000000000000000000000000000000000;
        res[2] = 0x00F8e64a8651E3479A0B20F46b1D462Fe29D6aBc;
    }

    function _getRawScalingFactors() internal pure returns (uint256[] memory res) {
        res = new uint256[](3);
        res[0] = res[1] = res[2] = 1e18;
    }

    function _getExemption() internal pure returns (bool[] memory res) {
        res = new bool[](3);
        res[0] = res[1] = res[2] = false;
    }

    function getTokensIn() public pure override returns (address[] memory res) {
        res = new address[](3);
        res[0] = WSTETH;
        res[1] = ANKRETH;
        res[2] = LP;
    }

    function getTokensOut() public pure override returns (address[] memory res) {
        res = new address[](3);
        res[0] = WSTETH;
        res[1] = ANKRETH;
        res[2] = LP;
    }

    function isValidTokenIn(address token) public pure override returns (bool) {
        return (token == WSTETH || token == ANKRETH || token == LP);
    }

    function isValidTokenOut(address token) public pure override returns (bool) {
        return (token == WSTETH || token == ANKRETH || token == LP);
    }
}
