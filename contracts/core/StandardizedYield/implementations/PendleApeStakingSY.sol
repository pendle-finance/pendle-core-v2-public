// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../SYBaseAutoCompound.sol";
import "../../../interfaces/IApeStaking.sol";

contract PendleApeStakingSY is SYBaseAutoCompound {
    using Math for uint256;

    uint256 public constant APE_COIN_POOL_ID = 0;

    address public immutable apeStaking;
    address public immutable apeCoin;

    constructor(
        string memory _name,
        string memory _symbol,
        address _apeCoin,
        address _apeStaking
    )
        SYBaseAutoCompound(_name, _symbol, _apeCoin) // solhint-disable-next-line no-empty-blocks
    {
        apeStaking = _apeStaking;
        apeCoin = _apeCoin;
        _safeApproveInf(_apeCoin, _apeStaking);
    }

    function _deposit(address, uint256 amountDeposited)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        _claimRewardsAndCompoundAsset();

        // The upcoming calculation can be reduced to amountDeposited.divDown(exchangeRate())
        // The following calculation is choosen instead to minimize precision error
        amountSharesOut = (amountDeposited * totalSupply()) / _getTotalAssetOwned();

        IApeStaking(apeStaking).depositSelfApeCoin(amountDeposited);
    }

    function _redeem(
        address receiver,
        address,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        _claimRewardsAndCompoundAsset();

        // The upcoming calculation can be reduced to amountSharesToRedeem.mulDown(exchangeRate())
        // The following calculation is choosen instead to minimize precision error
        amountTokenOut = (amountSharesToRedeem * _getTotalAssetOwned()) / totalSupply();

        IApeStaking(apeStaking).withdrawApeCoin(amountTokenOut, receiver);
    }

    function _claimRewardsAndCompoundAsset()
        internal
        virtual
        override
        returns (uint256 totalAssetCompounded)
    {
        IApeStaking(apeStaking).claimSelfApeCoin();
        totalAssetCompounded = _selfBalance(apeCoin);
        IApeStaking(apeStaking).depositSelfApeCoin(totalAssetCompounded);
    }

    function _getTotalAssetOwned()
        internal
        view
        virtual
        override
        returns (uint256 totalAssetOwned)
    {
        (uint256 stakedAmount, ) = IApeStaking(apeStaking).addressPosition(address(this));
        uint256 unclaimedAmount = IApeStaking(apeStaking).pendingRewards(
            APE_COIN_POOL_ID,
            address(this),
            0
        );
        uint256 floatingAmount = _selfBalance(apeCoin);
        totalAssetOwned = stakedAmount + unclaimedAmount + floatingAmount;
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(address, uint256 amountTokenToDeposit)
        internal
        view
        override
        returns (uint256 amountSharesOut)
    {
        amountSharesOut = (amountTokenToDeposit * totalSupply()) / _getTotalAssetOwned();
    }

    function _previewRedeem(address, uint256 amountSharesToRedeem)
        internal
        view
        override
        returns (uint256 amountTokenOut)
    {
        amountTokenOut = (amountSharesToRedeem * _getTotalAssetOwned()) / totalSupply();
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](1);
        res[0] = apeCoin;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](1);
        res[0] = apeCoin;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == apeCoin;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == apeCoin;
    }

    function assetInfo()
        external
        view
        returns (
            AssetType assetType,
            address assetAddress,
            uint8 assetDecimals
        )
    {
        return (AssetType.TOKEN, apeCoin, IERC20Metadata(apeCoin).decimals());
    }
}
