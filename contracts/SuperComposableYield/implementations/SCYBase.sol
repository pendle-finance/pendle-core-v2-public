// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "../ISuperComposableYield.sol";
import "./RewardManager.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../../libraries/math/Math.sol";
import "../SCYUtils.sol";

abstract contract SCYBase is ERC20, ISuperComposableYield, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    event UpdateScyIndex(uint256 scyIndex);

    uint8 private immutable _scyDecimals;
    uint8 private immutable _assetDecimals;
    bytes32 private immutable _assetId;

    mapping(address => uint256) internal lastBalanceOf;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __scyDecimals,
        uint8 __assetDecimals,
        bytes32 __assetId
    ) ERC20(_name, _symbol) {
        _scyDecimals = __scyDecimals;
        _assetDecimals = __assetDecimals;
        _assetId = __assetId;
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function mint(
        address receiver,
        address baseTokenIn,
        uint256 amountBaseToPull,
        uint256 minAmountScyOut
    ) external nonReentrant returns (uint256 amountScyOut) {
        IERC20(baseTokenIn).safeTransferFrom(msg.sender, address(this), amountBaseToPull);
        amountScyOut = _mintFresh(receiver, baseTokenIn, minAmountScyOut);
    }

    function redeem(
        address receiver,
        address baseTokenOut,
        uint256 amountScyToPull,
        uint256 minAmountBaseOut
    ) external nonReentrant returns (uint256 amountBaseOut) {
        transferFrom(msg.sender, address(this), amountScyToPull);
        amountBaseOut = _redeemFresh(receiver, baseTokenOut, minAmountBaseOut);
    }

    function mintNoPull(
        address receiver,
        address baseTokenIn,
        uint256 minAmountScyOut
    ) external virtual override nonReentrant returns (uint256) {
        return _mintFresh(receiver, baseTokenIn, minAmountScyOut);
    }

    function redeemNoPull(
        address receiver,
        address baseTokenOut,
        uint256 minAmountBaseOut
    ) external virtual override nonReentrant returns (uint256) {
        return _redeemFresh(receiver, baseTokenOut, minAmountBaseOut);
    }

    function _mintFresh(
        address receiver,
        address baseTokenIn,
        uint256 minAmountScyOut
    ) internal virtual returns (uint256 amountScyOut) {
        require(isValidBaseToken(baseTokenIn), "invalid base token");

        uint256 amountBaseIn = _afterReceiveToken(baseTokenIn);

        amountScyOut = _deposit(baseTokenIn, amountBaseIn);

        require(amountScyOut >= minAmountScyOut, "insufficient out");

        _mint(receiver, amountScyOut);
    }

    function _redeemFresh(
        address receiver,
        address baseTokenOut,
        uint256 minAmountBaseOut
    ) internal virtual returns (uint256 amountBaseOut) {
        require(isValidBaseToken(baseTokenOut), "invalid base token");

        uint256 amountScyRedeem = balanceOf(address(this));

        _burn(address(this), amountScyRedeem);

        amountBaseOut = _redeem(baseTokenOut, amountScyRedeem);

        require(amountBaseOut >= minAmountBaseOut, "insufficient out");

        IERC20(baseTokenOut).safeTransfer(receiver, amountBaseOut);
        _afterSendToken(baseTokenOut);
    }

    function _deposit(address token, uint256 amountBase)
        internal
        virtual
        returns (uint256 amountScyOut);

    function _redeem(address token, uint256 amountScy)
        internal
        virtual
        returns (uint256 amountBaseOut);

    /*///////////////////////////////////////////////////////////////
                               SCY-INDEX
    //////////////////////////////////////////////////////////////*/

    function scyIndexCurrent() external virtual override returns (uint256 res);

    function scyIndexStored() external view virtual override returns (uint256 res);

    /*///////////////////////////////////////////////////////////////
                MISC METADATA FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return _scyDecimals;
    }

    function assetDecimals() external view virtual returns (uint8) {
        return _assetDecimals;
    }

    function assetId() external view returns (bytes32) {
        return _assetId;
    }

    function getBaseTokens() external view virtual override returns (address[] memory res);

    function isValidBaseToken(address token) public view virtual override returns (bool);

    /// @dev token should not be address(this) since it's expected that all scy in this contract
    /// are for redemption, so updating the mapping is redundant
    function _afterReceiveToken(address token) internal virtual returns (uint256 res) {
        assert(token != address(this));
        uint256 curBalance = IERC20(token).balanceOf(address(this));
        res = curBalance - lastBalanceOf[token];
        lastBalanceOf[token] = curBalance;
    }

    /// @dev token should not be address(this)
    function _afterSendToken(address token) internal virtual {
        assert(token != address(this));
        lastBalanceOf[token] = IERC20(token).balanceOf(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                            TRANSFER HOOKS
    //////////////////////////////////////////////////////////////*/
}
