// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.17;

import "../../../libraries/TokenHelper.sol";
import "../../../../interfaces/Camelot/ICamelotNFTFactory.sol";
import "../../../../interfaces/Camelot/ICamelotNFTPool.sol";
import "../../../../interfaces/Camelot/ICamelotNitroPool.sol";
import "../../../../interfaces/Camelot/ICamelotNFTHandler.sol";
import "../../../../interfaces/Camelot/IXGrail.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @dev This contract should leave at least MINIMUM_LIQUIDITY in NftPool position
 * to protect the position from being destroyed
 *
 * The reason for this is that once the position is destroyed, the deallocation of xGrail
 * will be forced to occur and take away fees from our xGRAIL boosting
 */
contract PendleCamelotRewardHelper is TokenHelper, ICamelotNFTHandler {
    uint256 public constant POSITION_UNINITIALIZED = type(uint256).max;
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    address public immutable nftPool;
    address public immutable nitroPool;
    address public immutable yieldBooster;
    address public immutable GRAIL;
    address public immutable xGRAIL;
    uint256 public positionId = POSITION_UNINITIALIZED;

    error InvalidTokenId(uint256 tokenId, uint256 positionId);

    modifier ensureValidTokenId(uint256 tokenId) {
        // Not allow receiving NFT from unwanted sources
        if (tokenId != positionId) {
            revert InvalidTokenId(tokenId, positionId);
        }
        _;
    }

    constructor(address _nitroPool, address _lp) {
        nitroPool = _nitroPool;
        nftPool = ICamelotNitroPool(nitroPool).nftPool();
        GRAIL = ICamelotNitroPool(nitroPool).grailToken();
        xGRAIL = ICamelotNitroPool(nitroPool).xGrailToken();
        yieldBooster = ICamelotNFTPool(nftPool).yieldBooster();

        _safeApproveInf(_lp, nftPool);
        IXGrail(xGRAIL).approveUsage(yieldBooster, type(uint256).max);
    }

    /**
     * @dev Though xGRAIL can be vested into GRAIL through vesting, it's not possible
     * to distribute this reward fairly on-chain.
     *
     * We decided to go with the second option (keep allocating xGRAIL to boost APR)
     */
    function _allocateXGrail() internal {
        uint256 amount = _selfBalance(xGRAIL);
        if (amount == 0) return;

        // there should be no reward without minimum liquidity minted
        assert(positionId != POSITION_UNINITIALIZED);
        
        IXGrail(xGRAIL).allocate(yieldBooster, amount, abi.encode(nftPool, positionId));
    }

    function _increaseNftPoolPosition(
        uint256 amountLp
    ) internal returns (uint256 amountLpAccountedForUser) {
        // first time minting from this contract
        if (positionId == POSITION_UNINITIALIZED) {
            positionId = ICamelotNFTPool(nftPool).lastTokenId() + 1;
            ICamelotNFTPool(nftPool).createPosition(amountLp, 0);

            // deposit nft to nitro pool (first time)
            _depositToNitroPool();

            return amountLp - MINIMUM_LIQUIDITY;
        } else {
            // theres not a need to call nitro pool as Camelot nitro pool has a callback
            // on nft pool position increases
            ICamelotNFTPool(nftPool).addToPosition(positionId, amountLp);
            return amountLp;
        }
    }

    function _removeNftPoolPosition(uint256 amountLp) internal {
        _withdrawFromNitroPool();
        ICamelotNFTPool(nftPool).withdrawFromPosition(positionId, amountLp);
        _depositToNitroPool();
    }

    function _depositToNitroPool() private {
        // Nitro pool's on receive callback will execute the accounting logic
        IERC721(nftPool).safeTransferFrom(address(this), nitroPool, positionId);
    }

    function _withdrawFromNitroPool() private {
        ICamelotNitroPool(nitroPool).withdraw(positionId);
    }

    /**
     * ==================================================================
     *                      CAMELOT NFT RELATED
     * ==================================================================
     */

    function onERC721Received(
        address,
        address,
        uint256 tokenId,
        bytes calldata
    ) external ensureValidTokenId(tokenId) returns (bytes4) {
        return _ERC721_RECEIVED;
    }

    function onNFTHarvest(
        address,
        address,
        uint256 tokenId,
        uint256,
        uint256
    ) external ensureValidTokenId(tokenId) returns (bool) {
        return true;
    }

    function onNFTAddToPosition(
        address,
        uint256 tokenId,
        uint256
    ) external ensureValidTokenId(tokenId) returns (bool) {
        return true;
    }

    function onNFTWithdraw(
        address,
        uint256 tokenId,
        uint256
    ) external ensureValidTokenId(tokenId) returns (bool) {
        return true;
    }
}
