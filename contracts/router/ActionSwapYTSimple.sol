// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IPActionSwapYTSimple} from "../interfaces/IPActionSwapYTSimple.sol";

import {IStandardizedYield} from "../interfaces/IStandardizedYield.sol";
import {IPMarket} from "../interfaces/IPMarket.sol";
import {IPYieldToken} from "../interfaces/IPYieldToken.sol";
import {TokenInput} from "../interfaces/IPAllActionTypeV3.sol";

import {PMath} from "../core/libraries/math/PMath.sol";

import {ActionBase} from "./base/ActionBase.sol";
import {ActionBaseSimple} from "./base/ActionBaseSimple.sol";

contract ActionSwapYTSimple is IPActionSwapYTSimple, ActionBase, ActionBaseSimple {
    using PMath for uint256;

    // ------------------ SWAP TOKEN FOR YT ------------------

    function swapExactTokenForYtSimple(
        address receiver,
        address market,
        uint256 minYtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netYtOut, uint256 netSyFee, uint256 netSyInterm) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        netSyInterm = _mintSyFromToken(address(this), address(SY), 1, input);
        (netYtOut, netSyFee) = _swapExactSyForYtSimple(receiver, market, SY, YT, netSyInterm, minYtOut);

        emit SwapYtAndToken(
            msg.sender,
            market,
            input.tokenIn,
            receiver,
            netYtOut.Int(),
            input.netTokenIn.neg(),
            netSyInterm
        );
    }

    function swapExactSyForYtSimple(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minYtOut
    ) external returns (uint256 netYtOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();
        _transferFrom(SY, msg.sender, address(this), exactSyIn);

        (netYtOut, netSyFee) = _swapExactSyForYtSimple(receiver, market, SY, YT, exactSyIn, minYtOut);
        emit SwapYtAndSy(msg.sender, market, receiver, netYtOut.Int(), exactSyIn.neg());
    }
}
