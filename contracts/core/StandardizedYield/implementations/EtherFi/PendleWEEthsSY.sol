// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "../PendleERC20SYUpg.sol";
import "../../../../interfaces/EtherFi/IVedoTeller.sol";
import "../../../../interfaces/EtherFi/IVedoAccountant.sol";

contract PendleWEEthsSY is PendleERC20SYUpg {
    using PMath for uint256;

    // solhint-disable immutable-vars-naming
    address public immutable weETHs;
    address public immutable vedoTeller;
    address public immutable vedoAccountant;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address public constant EETH = 0x35fA164735182de50811E8e2E824cFb9B6118ac2;
    address public constant WSTETH = 0x35fA164735182de50811E8e2E824cFb9B6118ac2;

    constructor(address _erc20, address _vedoTeller) PendleERC20SYUpg(_erc20) {
        weETHs = _erc20;
        vedoTeller = _vedoTeller;
        vedoAccountant = IVedoTeller(vedoTeller).accountant();
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == weETHs) {
            return amountDeposited;
        }
        return IVedoTeller(vedoTeller).deposit(tokenIn, amountDeposited, 0);
    }

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == weETHs) {
            return amountTokenToDeposit;
        }
        uint256 rate = IVedoAccountant(vedoAccountant).getRateInQuoteSafe(tokenIn);
        amountSharesOut = amountTokenToDeposit.divDown(rate);
    }

    function getTokensIn() public view override returns (address[] memory res) {
        return ArrayLib.create(weETHs, WETH, WEETH, EETH, WSTETH);
    }
}
