// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../SYBaseWithRewards.sol";
import "../../../../interfaces/Sophon/ISophonFarming.sol";
import "../../../../interfaces/Sophon/IPSophonPointManager.sol";

contract PendleSophonFarmingSY is SYBaseWithRewards {
    using Address for address;

    address public immutable sophonFarming;
    uint256 public immutable pid;
    address public immutable pointManager;

    constructor(
        string memory _name,
        string memory _symbol,
        address _sophonFarming,
        uint256 _pid,
        address _pointManager
    ) SYBaseWithRewards(_name, _symbol, __getPoolDepositToken(_sophonFarming, _pid)) {
        sophonFarming = _sophonFarming;
        pid = _pid;
        pointManager = _pointManager;
        _safeApproveInf(yieldToken, _sophonFarming);
    }

    function __getPoolDepositToken(address _sophonFarming, uint256 _pid) internal view returns (address) {
        (address lp, , , , , , , , , ) = ISophonFarming(_sophonFarming).poolInfo(_pid);
        return lp;
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address /*tokenIn*/, uint256 amountDeposited) internal virtual override returns (uint256) {
        ISophonFarming(sophonFarming).deposit(pid, amountDeposited, 0);
        return amountDeposited;
    }

    function _redeem(
        address receiver,
        address,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256) {
        ISophonFarming(sophonFarming).withdraw(pid, amountSharesToRedeem);
        _transferOut(yieldToken, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return PMath.ONE;
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    function _getRewardTokens() internal view override returns (address[] memory) {
        return ArrayLib.create(pointManager);
    }

    function _redeemExternalReward() internal override {
        uint256 owningPoints = _getOwningPoints();
        if (owningPoints == 0) return;
        ISophonFarming(sophonFarming).transferPoints(pid, address(this), pointManager, owningPoints);
        IPSophonPointManager(pointManager).claimPointReceiptToken();
    }

    function _getOwningPoints() internal view returns (uint256) {
        return ISophonFarming(sophonFarming).pendingPoints(pid, address(this));
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address /*tokenIn*/,
        uint256 amountTokenToDeposit
    ) internal view override returns (uint256) {
        return amountTokenToDeposit;
    }

    function _previewRedeem(
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal view override returns (uint256) {
        return amountSharesToRedeem;
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        return ArrayLib.create(yieldToken);
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        return ArrayLib.create(yieldToken);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == yieldToken;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == yieldToken;
    }

    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, yieldToken, IERC20Metadata(yieldToken).decimals());
    }
}
