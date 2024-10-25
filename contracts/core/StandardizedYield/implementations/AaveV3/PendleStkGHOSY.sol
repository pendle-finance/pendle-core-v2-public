// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../SYBaseWithRewardsUpg.sol";
import "../../../../interfaces/AaveV3/IAaveStkGHO.sol";
import "../../../../interfaces/Angle/IAngleDistributor.sol";

contract PendleStkGHOSY is SYBaseWithRewardsUpg {
    event ClaimedOffchainGHO(uint256 amountClaimed);

    address public constant ANGLE_DISTRIBUTOR = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address public constant STKGHO = 0x1a88Df1cFe15Af22B3c4c783D4e6F7F9e0C1885d;
    address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    address public constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    bytes32 public constant ZERO_REWARD_ERROR = 0x33d2eb294587ef7b32eb48e48695ebfec45a9c8922ec7d1c444cfad1fb208e8d;

    constructor() SYBaseUpg(STKGHO) {}

    function initialize() external initializer {
        __SYBaseUpg_init("SY stk GHO", "SY-stk-GHO");
        _safeApproveInf(GHO, STKGHO);
    }

    function _deposit(address tokenIn, uint256 amountDeposited) internal virtual override returns (uint256) {
        if (tokenIn == STKGHO) {
            return amountDeposited;
        }

        uint256 preBalance = _selfBalance(STKGHO);
        IAaveStkGHO(STKGHO).stake(address(this), amountDeposited);
        return _selfBalance(STKGHO) - preBalance;
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256) {
        if (tokenOut == STKGHO) {
            _transferOut(STKGHO, receiver, amountSharesToRedeem);
            return amountSharesToRedeem;
        }

        uint256 amountOut = IAaveStkGHO(STKGHO).previewRedeem(amountSharesToRedeem);
        IAaveStkGHO(STKGHO).redeem(receiver, amountSharesToRedeem);
        return amountOut;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return IAaveStkGHO(STKGHO).getExchangeRate();
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {IStandardizedYield-getRewardTokens}
     */
    function _getRewardTokens() internal pure override returns (address[] memory) {
        return ArrayLib.create(AAVE);
    }

    function _redeemExternalReward() internal override {
        try IAaveStkGHO(STKGHO).claimRewards(address(this), type(uint256).max) {} catch Error(
            string memory errorString
        ) {
            if (keccak256(abi.encodePacked(errorString)) != ZERO_REWARD_ERROR) {
                revert(errorString);
            }
        }
    }

    function claimOffchainGHORewards(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external onlyOwner {
        uint256 preBalance = _selfBalance(GHO);
        IAngleDistributor(ANGLE_DISTRIBUTOR).claim(users, tokens, amounts, proofs);
        uint256 amountClaimed = _selfBalance(GHO) - preBalance;

        if (amountClaimed > 0) {
            _transferOut(GHO, msg.sender, amountClaimed);
            emit ClaimedOffchainGHO(amountClaimed);
        }
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view override returns (uint256 amountSharesOut) {
        if (tokenIn == STKGHO) return amountTokenToDeposit;
        return IAaveStkGHO(STKGHO).previewStake(amountTokenToDeposit);
    }

    function _previewRedeem(
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal view override returns (uint256 amountTokenOut) {
        if (tokenOut == STKGHO) return amountSharesToRedeem;
        return IAaveStkGHO(STKGHO).previewRedeem(amountSharesToRedeem);
    }

    function getTokensIn() public view virtual override returns (address[] memory) {
        return ArrayLib.create(GHO, STKGHO);
    }

    function getTokensOut() public view virtual override returns (address[] memory) {
        return ArrayLib.create(STKGHO);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == GHO || token == STKGHO;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == STKGHO;
    }

    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, GHO, IERC20Metadata(GHO).decimals());
    }
}
