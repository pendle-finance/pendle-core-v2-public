// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "../misc/PendleJoeSwapHelper.sol";
import "../../LiquidYieldToken/ILiquidYieldToken.sol";
import "../../interfaces/IPYieldToken.sol";

contract PendleRouterLytAndForge is PendleJoeSwapHelper {
    using SafeERC20 for IERC20;

    constructor(address _joeRouter, address _joeFactory)
        PendleJoeSwapHelper(_joeRouter, _joeFactory)
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function mintLytFromRawToken(
        uint256 netRawTokenIn,
        address LYT,
        uint256 minLytOut,
        address recipient,
        address[] calldata path
    ) public returns (uint256 netLytOut) {
        if (path.length == 1) {
            IERC20(path[0]).transferFrom(msg.sender, LYT, netRawTokenIn);
        } else {
            IERC20(path[0]).transferFrom(msg.sender, _getFirstPair(path), netRawTokenIn);
            _swapExactIn(path, netRawTokenIn, LYT);
        }

        netLytOut = _mintLytFromRawToken(LYT, minLytOut, recipient, path);
    }

    function redeemLytToRawToken(
        address LYT,
        uint256 netLytIn,
        uint256 minRawTokenOut,
        address recipient,
        address[] calldata path
    ) public returns (uint256 netRawTokenOut) {
        IERC20(LYT).safeTransferFrom(msg.sender, LYT, netLytIn);

        netRawTokenOut = _redeemLytToRawToken(LYT, minRawTokenOut, recipient, path);
    }

    function mintYoFromRawToken(
        uint256 netRawTokenIn,
        address YT,
        uint256 minYoOut,
        address recipient,
        address[] calldata path
    ) public returns (uint256 netYoOut) {
        address LYT = IPYieldToken(YT).LYT();

        mintLytFromRawToken(netRawTokenIn, LYT, 1, YT, path);

        netYoOut = IPYieldToken(YT).mintYO(recipient);

        require(netYoOut >= minYoOut, "insufficient YO out");
    }

    function redeemYoToRawToken(
        address YT,
        uint256 netYoIn,
        uint256 minRawTokenOut,
        address recipient,
        address[] calldata path
    ) public returns (uint256 netRawTokenOut) {
        address OT = IPYieldToken(YT).OT();
        address LYT = IPYieldToken(YT).LYT();

        bool isNeedToBurnYt = (IPBaseToken(YT).isExpired() == false);

        IERC20(OT).safeTransferFrom(msg.sender, YT, netYoIn);
        if (isNeedToBurnYt) IERC20(YT).safeTransferFrom(msg.sender, YT, netYoIn);

        IPYieldToken(YT).redeemYO(LYT);

        netRawTokenOut = _redeemLytToRawToken(LYT, minRawTokenOut, recipient, path);
    }

    function _mintLytFromRawToken(
        address LYT,
        uint256 minLytOut,
        address recipient,
        address[] calldata path
    ) internal returns (uint256 netLytOut) {
        address baseToken = path[path.length - 1];
        netLytOut = ILiquidYieldToken(LYT).mint(recipient, baseToken, minLytOut);
    }

    function _redeemLytToRawToken(
        address LYT,
        uint256 minRawTokenOut,
        address recipient,
        address[] calldata path
    ) internal returns (uint256 netRawTokenOut) {
        address baseToken = path[0];
        if (path.length == 1) {
            netRawTokenOut = ILiquidYieldToken(LYT).redeem(recipient, baseToken, minRawTokenOut);
        } else {
            netRawTokenOut = ILiquidYieldToken(LYT).redeem(
                _getFirstPair(path),
                baseToken,
                minRawTokenOut
            );
            _swapExactIn(path, netRawTokenOut, recipient);
        }
    }
}
