// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./base/PendleAuraBalancerStableLPSY.sol";
import "../../../../interfaces/IWETH.sol";
import "../../../libraries/Errors.sol";

contract PendleAuraWethRethSY is PendleAuraBalancerStableLPSY {
    using SafeERC20 for IERC20;

    address public constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;

    uint256 internal constant AURA_PID = 15;
    address internal constant LP = 0x1E19CF2D73a72Ef1332C882F20534B6519Be0276;

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
        res[0] = RETH;
        res[1] = WETH;
    }

    function _getRateProviders() internal view virtual returns (address[] memory res) {
        res = new address[](2);
        res[0] = 0x1a8F81c256aee9C640e14bB0453ce247ea0DFE6F;
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
        res = new address[](4);
        res[0] = LP;
        res[1] = RETH;
        res[2] = WETH;
        res[3] = NATIVE;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](4);
        res[0] = LP;
        res[1] = RETH;
        res[2] = WETH;
        res[3] = NATIVE;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return (token == LP || token == RETH || token == WETH || token == NATIVE);
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return (token == LP || token == RETH || token == WETH || token == NATIVE);
    }
}
