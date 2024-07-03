// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "../PendleERC20SYUpg.sol";
import "../../../../interfaces/EtherFi/IVedaTeller.sol";
import "../../../../interfaces/EtherFi/IVedaAccountant.sol";

contract PendleWEEthsSY is PendleERC20SYUpg {
    using PMath for uint256;

    // solhint-disable immutable-vars-naming
    // solhint-disable const-name-snakecase
    // solhint-disable ordering

    address public constant weETHs = 0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88;
    address public constant vedaTeller = 0x99dE9e5a3eC2750a6983C8732E6e795A35e7B861;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address public constant EETH = 0x35fA164735182de50811E8e2E824cFb9B6118ac2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address public immutable vedaAccountant;

    constructor() PendleERC20SYUpg(weETHs) {
        vedaAccountant = IVedaTeller(vedaTeller).accountant();
    }

    function approveAllForTeller() external {
        _safeApproveInf(WETH, weETHs);
        _safeApproveInf(WEETH, weETHs);
        _safeApproveInf(EETH, weETHs);
        _safeApproveInf(WSTETH, weETHs);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == weETHs) {
            return amountDeposited;
        }
        return IVedaTeller(vedaTeller).bulkDeposit(tokenIn, amountDeposited, 0, address(this));
    }

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == weETHs) {
            return amountTokenToDeposit;
        }
        uint256 rate = IVedaAccountant(vedaAccountant).getRateInQuoteSafe(tokenIn);
        amountSharesOut = amountTokenToDeposit.divDown(rate);
    }

    function isValidTokenIn(address token) public pure override returns (bool) {
        return token == weETHs || token == WETH || token == WEETH || token == EETH || token == WSTETH;
    }

    function getTokensIn() public pure override returns (address[] memory res) {
        return ArrayLib.create(weETHs, WETH, WEETH, EETH, WSTETH);
    }
}
