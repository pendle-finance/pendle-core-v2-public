// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./base/PendleAuraBalancerStableLPSY.sol";

/**
 * @dev open TODO:
 * - Override deposit/redeem to also (un)wrap ETH
 */
contract PendleAuraWethRethSY is PendleAuraBalancerStableLPSY {
    using SafeERC20 for IERC20;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;

    uint256 internal constant AURA_PID = 15;
    address internal constant LP = 0x1E19CF2D73a72Ef1332C882F20534B6519Be0276;

    constructor(
        string memory _name,
        string memory _symbol,
        StablePreview _stablePreview
    ) PendleAuraBalancerStableLPSY(_name, _symbol, LP, AURA_PID, _stablePreview) {}

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
