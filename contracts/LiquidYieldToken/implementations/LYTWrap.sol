// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import "../ILiquidYieldTokenWrap.sol";
import "./RewardManager.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../../libraries/math/FixedPoint.sol";

/**
# CONDITIONS TO USE THIS PRESET:
- the token's balance must be static (i.e not increase on its own). Some examples of tokens don't
satisfy this restriction is AaveV2's aToken

# OVERVIEW OF THIS PRESET
- 1 unit of YieldToken is wrapped into 1 unit of LYT
*/
abstract contract LYTWrap is ERC20, ILiquidYieldTokenWrap {
    using SafeERC20 for IERC20;
    using FixedPoint for uint256;

    uint8 private immutable _lytdecimals;
    uint8 private immutable _assetDecimals;

    address public immutable yieldToken;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __lytdecimals,
        uint8 __assetDecimals,
        address _yieldToken
    ) ERC20(_name, _symbol) {
        _lytdecimals = __lytdecimals;
        _assetDecimals = __assetDecimals;

        yieldToken = _yieldToken;

        // Children's constructor needs to approve the address that mints the yieldToken
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function depositBaseToken(
        address recipient,
        address baseTokenIn,
        uint256 amountBaseIn,
        uint256 minAmountLytOut
    ) public virtual override returns (uint256 amountLytOut) {
        require(isValidBaseToken(baseTokenIn), "invalid base token");

        IERC20(baseTokenIn).safeTransferFrom(msg.sender, address(this), amountBaseIn);

        amountLytOut = _baseToYield(baseTokenIn, amountBaseIn);

        require(amountLytOut >= minAmountLytOut, "insufficient out");

        _mint(recipient, amountLytOut);
    }

    function redeemToBaseToken(
        address recipient,
        uint256 amountLytRedeem,
        address baseTokenOut,
        uint256 minAmountBaseOut
    ) public virtual override returns (uint256 amountBaseOut) {
        require(isValidBaseToken(baseTokenOut), "invalid base token");

        _burn(msg.sender, amountLytRedeem);

        amountBaseOut = _yieldToBase(baseTokenOut, amountLytRedeem);

        require(amountBaseOut >= minAmountBaseOut, "insufficient out");

        IERC20(baseTokenOut).safeTransfer(recipient, amountBaseOut);
    }

    function _baseToYield(address token, uint256 amountBase)
        internal
        virtual
        returns (uint256 amountYieldOut);

    function _yieldToBase(address token, uint256 amountYield)
        internal
        virtual
        returns (uint256 amountBaseOut);

    /*///////////////////////////////////////////////////////////////
                DEPOSIT/REDEEM USING THE YIELD TOKEN
    //////////////////////////////////////////////////////////////*/

    function depositYieldToken(
        address recipient,
        uint256 amountYieldIn,
        uint256 minAmountLytOut
    ) public virtual override returns (uint256 amountLytOut) {
        IERC20(yieldToken).safeTransferFrom(msg.sender, address(this), amountYieldIn);

        amountLytOut = amountYieldIn;

        require(amountLytOut >= minAmountLytOut, "insufficient out");

        _mint(recipient, amountLytOut);
    }

    function redeemToYieldToken(
        address recipient,
        uint256 amountLytRedeem,
        uint256 minAmountYieldOut
    ) public virtual override returns (uint256 amountYieldOut) {
        _burn(msg.sender, amountLytRedeem);

        amountYieldOut = amountLytRedeem;

        require(amountYieldOut >= minAmountYieldOut, "insufficient out");

        IERC20(yieldToken).safeTransfer(recipient, amountYieldOut);
    }

    /*///////////////////////////////////////////////////////////////
                               LYT-INDEX
    //////////////////////////////////////////////////////////////*/
    function assetBalanceOf(address user) public virtual override returns (uint256) {
        return balanceOf(user).mulDown(lytIndexCurrent());
    }

    /// lytIndexCurrent must be non-decreasing
    function lytIndexCurrent() public virtual override returns (uint256 res);

    function lytIndexStored() public view virtual override returns (uint256 res);

    /*///////////////////////////////////////////////////////////////
                MISC METADATA FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return _lytdecimals;
    }

    function assetDecimals() public view virtual returns (uint8) {
        return _assetDecimals;
    }

    function getBaseTokens() public view virtual override returns (address[] memory res);

    function isValidBaseToken(address token) public view virtual override returns (bool);

    /*///////////////////////////////////////////////////////////////
                            TRANSFER HOOKS
    //////////////////////////////////////////////////////////////*/
}
