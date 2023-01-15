// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./StorageLayout.sol";
import "../../interfaces/IDiamondCut.sol";

contract DiamondCutFacet is StorageLayout, IDiamondCut {
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
