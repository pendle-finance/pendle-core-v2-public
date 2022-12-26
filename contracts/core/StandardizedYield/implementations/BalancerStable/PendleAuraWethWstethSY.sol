// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./base/PendleAuraBalancerStableLPSY.sol";

contract PendleAuraWethWstethSY is PendleAuraBalancerStableLPSY {
    using SafeERC20 for IERC20;

    uint256 internal constant AURA_PID = 29;
    address internal constant LP = 0x32296969Ef14EB0c6d29669C550D4a0449130230;

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
        res = new address[](2);
        res[0] = WSTETH;
        res[1] = WETH;
    }

    function _getRateProviders() internal view virtual returns (address[] memory res) {
        res = new address[](2);
        res[0] = 0x72D07D7DcA67b8A406aD1Ec34ce969c90bFEE768;
        res[1] = 0x0000000000000000000000000000000000000000;
    }

    function _getRawScalingFactors() internal view virtual returns (uint256[] memory res) {
        res = new uint256[](2);
        res[0] = 1e18;
        res[1] = 1e18;
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
        // res.isExemptFromYieldProtocolFee is not filled
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](5);
        res[0] = LP;
        res[1] = WSTETH;
        res[2] = WETH;
        res[3] = STETH;
        res[4] = NATIVE;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](5);
        res[0] = LP;
        res[1] = WSTETH;
        res[2] = WETH;
        res[3] = STETH;
        res[4] = NATIVE;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return (token == LP ||
            token == WSTETH ||
            token == WETH ||
            token == STETH ||
            token == NATIVE);
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return (token == LP ||
            token == WSTETH ||
            token == WETH ||
            token == STETH ||
            token == NATIVE);
    }
}
