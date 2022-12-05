// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../SYBaseAutoCompound.sol";
import "../../../interfaces/IApeStaking.sol";
import "../../libraries/BoringOwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract PendleApeStakingSY is
    Initializable,
    UUPSUpgradeable,
    BoringOwnableUpgradeable,
    SYBaseAutoCompound
{
    using Math for uint256;

    uint256 public constant APE_COIN_POOL_ID = 0;
    uint256 public constant MIN_APE_DEPOSIT = 10**18;
    uint256 public constant EPOCH_LENGTH = 1 hours;

    address public immutable apeStaking;
    address public immutable apeCoin;

    uint256 private lastRewardClaimedEpoch;
    uint256[48] private __gap;

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

        lastRewardClaimedEpoch = _getCurrentEpochId();
        __BoringOwnable_init();
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

    function _claimRewardsAndCompoundAsset() internal virtual override {
        // Claim reward
        uint256 currentEpochId = _getCurrentEpochId();
        if (currentEpochId != lastRewardClaimedEpoch) {
            IApeStaking(apeStaking).claimSelfApeCoin();
            lastRewardClaimedEpoch = currentEpochId;
        }

        // Deposit APE
        uint256 amountAssetToCompound = _selfBalance(apeCoin);
        if (amountAssetToCompound > MIN_APE_DEPOSIT) {
            IApeStaking(apeStaking).depositSelfApeCoin(amountAssetToCompound);
        }
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

    function _getCurrentEpochId() private view returns (uint256) {
        return block.timestamp / EPOCH_LENGTH;
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

    /*///////////////////////////////////////////////////////////////
                FUNCTIONS FOR PROXY/UPGRADABLE
    //////////////////////////////////////////////////////////////*/

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
