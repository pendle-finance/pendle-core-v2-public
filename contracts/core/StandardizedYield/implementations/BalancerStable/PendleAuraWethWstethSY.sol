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
        res[0] = WSTETH;
        res[1] = WETH;
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
