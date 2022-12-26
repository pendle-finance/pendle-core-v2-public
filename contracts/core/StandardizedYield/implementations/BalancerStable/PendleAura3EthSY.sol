// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./base/PendleAuraBalancerStableLPSY.sol";

contract PendleAura3EthSY is PendleAuraBalancerStableLPSY {
    using SafeERC20 for IERC20;

    address public constant SFRXETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address public constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;

    uint256 internal constant AURA_PID = 13;
    address internal constant LP = 0x8e85e97ed19C0fa13B2549309965291fbbc0048b;

    constructor(
        string memory _name,
        string memory _symbol,
        IBalancerStablePreview _previewHelper
    ) PendleAuraBalancerStableLPSY(_name, _symbol, LP, AURA_PID, _previewHelper) {}

    function _getPoolTokenAddresses()
        internal
        view
        virtual
        override
        returns (address[] memory res)
    {
        res = new address[](4);
        res[0] = WSTETH;
        res[1] = LP;
        res[2] = SFRXETH;
        res[3] = RETH;
    }

    function _getRateProviders() internal view virtual returns (address[] memory res) {
        res = new address[](4);
        res[0] = 0x72D07D7DcA67b8A406aD1Ec34ce969c90bFEE768;
        res[1] = 0x0000000000000000000000000000000000000000;
        res[2] = 0x302013E7936a39c358d07A3Df55dc94EC417E3a1;
        res[3] = 0x1a8F81c256aee9C640e14bB0453ce247ea0DFE6F;
    }

    function _getRawScalingFactors() internal view virtual returns (uint256[] memory res) {
        res = new uint256[](4);
        res[0] = 1e18;
        res[1] = 1e18;
        res[2] = 1e18;
        res[3] = 1e18;
    }

    function _getExemption() internal view virtual returns (bool[] memory res) {
        res = new bool[](4);
        res[0] = false;
        res[1] = false;
        res[2] = false;
        res[3] = false;
    }

    function _getImmutablePoolData()
        internal
        view
        virtual
        override
        returns (IBalancerStablePreview.StablePoolData memory res)
    {
        res.poolTokens = _getPoolTokenAddresses();
        res.rateProviders = _getRateProviders();
        res.rawScalingFactors = _getRawScalingFactors();
        res.isExemptFromYieldProtocolFee = _getExemption();
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](4);
        res[0] = WSTETH;
        res[1] = LP;
        res[2] = SFRXETH;
        res[3] = RETH;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](4);
        res[0] = WSTETH;
        res[1] = LP;
        res[2] = SFRXETH;
        res[3] = RETH;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return (token == WSTETH || token == LP || token == SFRXETH || token == RETH);
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return (token == WSTETH || token == LP || token == SFRXETH || token == RETH);
    }
}
