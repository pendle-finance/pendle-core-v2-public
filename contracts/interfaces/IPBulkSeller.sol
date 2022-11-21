// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../core/BulkSeller/BulkSellerMathCore.sol";

interface IPBulkSeller {
    function swapExactSyForToken(
        address receiver,
        uint256 exactSyIn,
        uint256 minTokenOut
    ) external returns (uint256 netTokenOut);

    function swapExactTokenForSy(
        address receiver,
        uint256 netTokenIn,
        uint256 minSyOut
    ) external returns (uint256 netSyOut);

    function SY() external view returns (address);

    function token() external view returns (address);

    function readState() external view returns (BulkSellerState memory);
}
