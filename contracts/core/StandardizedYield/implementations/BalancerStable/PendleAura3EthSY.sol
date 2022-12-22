// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./base/PendleAuraBalancerStableLPSY.sol";

contract PendleAura3EthSY is PendleAuraBalancerStableLPSY {
    using SafeERC20 for IERC20;

    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant SFRXETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address public constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;

    uint256 internal constant AURA_PID = 13;
    address internal constant LP = 0x8e85e97ed19C0fa13B2549309965291fbbc0048b;

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
        res = new address[](4);
        res[0] = WSTETH;
        res[1] = LP;
        res[2] = SFRXETH;
        res[3] = RETH;
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
