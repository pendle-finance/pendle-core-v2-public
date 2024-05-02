// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../SYBase.sol";
import "../../../../interfaces/Swell/ISwellSimpleStakingERC20.sol";

contract PendleSwellStakingERC20SY is SYBase {
    using ArrayLib for address[];

    address public constant SWELL_STAKING = 0x38D43a6Cb8DA0E855A42fB6b0733A0498531d774;

    // solhint-disable immutable-vars-naming
    address public immutable stakeToken;

    constructor(string memory _name, string memory _symbol, address _stakeToken) SYBase(_name, _symbol, _stakeToken) {
        stakeToken = _stakeToken;
        _safeApproveInf(_stakeToken, SWELL_STAKING);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn != stakeToken) {
            amountDeposited = _wrapToStakeToken(tokenIn, amountDeposited);
        }
        ISwellSimpleStakingERC20(SWELL_STAKING).deposit(stakeToken, amountDeposited, address(this));
        return amountDeposited;
    }

    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 /*amountTokenOut*/) {
        ISwellSimpleStakingERC20(SWELL_STAKING).withdraw(stakeToken, amountSharesToRedeem, receiver);
        return amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/
    function exchangeRate() public view virtual override returns (uint256) {
        return PMath.ONE;
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit) internal view override returns (uint256) {
        if (tokenIn == stakeToken) {
            return amountTokenToDeposit;
        }
        return _previewToStakeToken(tokenIn, amountTokenToDeposit);
    }

    function _previewRedeem(
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal pure override returns (uint256 /*amountTokenOut*/) {
        return amountSharesToRedeem;
    }

    function getTokensIn() public view virtual override returns (address[] memory) {
        return ArrayLib.create(stakeToken).merge(_getAdditionalTokens());
    }

    function getTokensOut() public view virtual override returns (address[] memory) {
        return ArrayLib.create(stakeToken);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == stakeToken || _canWrapToStakeToken(token);
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == stakeToken;
    }

    function assetInfo()
        external
        view
        virtual
        returns (AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (AssetType.TOKEN, stakeToken, IERC20Metadata(stakeToken).decimals());
    }

    /*///////////////////////////////////////////////////////////////
                    ADDITIONAL TOKEN IN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getAdditionalTokens() internal view virtual returns (address[] memory) {}

    function _previewToStakeToken(address, uint256) internal view virtual returns (uint256) {
        assert(false);
    }

    function _wrapToStakeToken(address, uint256) internal virtual returns (uint256) {
        assert(false);
    }

    function _canWrapToStakeToken(address) internal view virtual returns (bool) {
        return false;
    }
}
