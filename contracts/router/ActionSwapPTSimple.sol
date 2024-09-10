// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IPActionSwapPTSimple} from "../interfaces/IPActionSwapPTSimple.sol";

import {IPMarket} from "../interfaces/IPMarket.sol";
import {IStandardizedYield} from "../interfaces/IStandardizedYield.sol";
import {TokenInput} from "../interfaces/IPAllActionTypeV3.sol";

import {PMath} from "../core/libraries/math/PMath.sol";

import {ActionBase} from "./base/ActionBase.sol";
import {ActionBaseSimple} from "./base/ActionBaseSimple.sol";
import {ApproxParams, emptyApproxParams} from "./base/ApproxParams.sol";

contract ActionSwapPTSimple is IPActionSwapPTSimple, ActionBase, ActionBaseSimple {
    using PMath for uint256;

    // ------------------ SWAP TOKEN FOR PT ------------------
    function swapExactTokenForPtSimple(
        address receiver,
        address market,
        uint256 minPtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
        netSyInterm = _mintSyFromToken(address(this), address(SY), 1, input);

        (netPtOut, netSyFee) = _swapExactSyForPtSimple(receiver, market, netSyInterm, minPtOut);
        emit SwapPtAndToken(
            msg.sender,
            market,
            input.tokenIn,
            receiver,
            netPtOut.Int(),
            input.netTokenIn.neg(),
            netSyInterm
        );
    }

    function swapExactSyForPtSimple(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minPtOut
    ) external returns (uint256 netPtOut, uint256 netSyFee) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
        _transferFrom(SY, msg.sender, address(this), exactSyIn);

        (netPtOut, netSyFee) = _swapExactSyForPtSimple(receiver, market, exactSyIn, minPtOut);
        emit SwapPtAndSy(msg.sender, market, receiver, netPtOut.Int(), exactSyIn.neg());
    }
}
