// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../SYBaseWithRewards.sol";
import "../../../../interfaces/Equilibria/IEquilibriaConverter.sol";
import "../../../../interfaces/Equilibria/IEquilibriaVault.sol";

contract PendleArbitrumEPendleSY is SYBaseWithRewards {
    using PMath for uint256;

    address public constant PENDLE = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8;
    address public constant EPENDLE = 0x3EaBE18eAE267D1B57f917aBa085bb5906114600;
    address public constant VAULT = 0x37227785a1f4545ed914690e395e4CFE96B8319f;
    address public constant CONVERTER = 0x6A82a15Da16bA35692d07c36954b444bEA896c60;
    address public constant EQB = 0xBfbCFe8873fE28Dfa25f1099282b088D52bbAD9C;
    address public constant MAXEQB = 0x96C4A48Abdf781e9c931cfA92EC0167Ba219ad8E;

    constructor() SYBaseWithRewards("SY Staked ePENDLE", "SY-stk-EPendle", VAULT) {
        _safeApproveInf(PENDLE, CONVERTER);
        _safeApproveInf(EPENDLE, VAULT);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == PENDLE) {
            (tokenIn, amountDeposited) = (EPENDLE, IEquilibriaConverter(CONVERTER).deposit(amountDeposited));
        }
        amountSharesOut = IEquilibriaVault(VAULT).deposit(amountDeposited);
    }

    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        amountTokenOut = IEquilibriaVault(VAULT).withdraw(amountSharesToRedeem);
        _transferOut(EPENDLE, receiver, amountTokenOut);
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates and updates the exchange rate of shares to underlying asset token
     * @dev It is the exchange rate of lp to underlying
     */
    function exchangeRate() public view virtual override returns (uint256) {
        return _getExchangeRate();
    }

    function _getExchangeRate() internal view returns (uint256) {
        uint256 b = IEquilibriaVault(VAULT).balance();
        uint256 s = IERC20(VAULT).totalSupply();
        return b.divDown(s);
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {IStandardizedYield-getRewardTokens}
     */
    function _getRewardTokens() internal pure override returns (address[] memory res) {
        return ArrayLib.create(EQB, MAXEQB);
    }

    function _redeemExternalReward() internal override {
        return IEquilibriaVault(VAULT).getReward(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view override returns (uint256 amountSharesOut) {
        if (tokenIn != EPENDLE) {
            (tokenIn, amountTokenToDeposit) = (
                EPENDLE,
                IEquilibriaConverter(CONVERTER).estimateTotalConversion(amountTokenToDeposit)
            );
        }
        uint256 r = _getExchangeRate();
        return amountTokenToDeposit.divDown(r);
    }

    function _previewRedeem(
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal view override returns (uint256 amountTokenOut) {
        uint256 r = _getExchangeRate();
        return amountSharesToRedeem.mulDown(r);
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        return ArrayLib.create(EPENDLE, PENDLE);
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        return ArrayLib.create(EPENDLE);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == EPENDLE || token == PENDLE;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == EPENDLE;
    }

    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, EPENDLE, IERC20Metadata(EPENDLE).decimals());
    }
}
