// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "../../interfaces/ISuperComposableYield.sol";
import "../../libraries/RewardManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../../libraries/math/Math.sol";
import "../../libraries/SCY/SCYUtils.sol";
import "../../libraries/helpers/TokenHelper.sol";
import "../../../contracts/core/PendleERC20.sol";

abstract contract SCYBase is ISuperComposableYield, PendleERC20, TokenHelper {
    using Math for uint256;

    address public immutable yieldToken;

    constructor(
        string memory _name,
        string memory _symbol,
        address _yieldToken
    ) PendleERC20(_name, _symbol, IERC20Metadata(_yieldToken).decimals()) {
        yieldToken = _yieldToken;
    }

    // solhint-disable no-empty-blocks
    receive() external payable {}

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-deposit}
     */
    function deposit(
        address receiver,
        address tokenIn,
        uint256 amountTokenToDeposit,
        uint256 minSharesOut
    ) external payable nonReentrant returns (uint256 amountSharesOut) {
        require(isValidBaseToken(tokenIn), "SCY: Invalid tokenIn");
        require(amountTokenToDeposit != 0, "SCY: amountTokenToDeposit cannot be 0");

        if (tokenIn == NATIVE) require(msg.value == amountTokenToDeposit, "SCY: eth mismatch");
        else _transferIn(tokenIn, msg.sender, amountTokenToDeposit);

        amountSharesOut = _deposit(tokenIn, amountTokenToDeposit);
        require(amountSharesOut >= minSharesOut, "SCY: insufficient out");

        _mint(receiver, amountSharesOut);
        emit Deposit(msg.sender, receiver, tokenIn, amountTokenToDeposit, amountSharesOut);
    }

    /**
     * @dev See {ISuperComposableYield-redeem}
     */
    function redeem(
        address receiver,
        uint256 amountSharesToRedeem,
        address tokenOut,
        uint256 minTokenOut
    ) external nonReentrant returns (uint256 amountTokenOut) {
        _burn(msg.sender, amountSharesToRedeem);
        amountTokenOut = _redeem(receiver, amountSharesToRedeem, tokenOut, minTokenOut);
    }

    function redeemAfterTransfer(
        address receiver,
        address tokenOut,
        uint256 minTokenOut
    ) external nonReentrant returns (uint256 amountTokenOut) {
        uint256 amountSharesToRedeem = balanceOf(address(this));
        _burn(address(this), amountSharesToRedeem);
        amountTokenOut = _redeem(receiver, amountSharesToRedeem, tokenOut, minTokenOut);
    }

    function _redeem(
        address receiver,
        uint256 amountSharesToRedeem,
        address tokenOut,
        uint256 minTokenOut
    ) internal returns (uint256 amountTokenOut) {
        require(isValidBaseToken(tokenOut), "SCY: invalid tokenOut");
        require(amountSharesToRedeem != 0, "SCY: amountSharesToRedeem cannot be 0");

        amountTokenOut = _redeem(tokenOut, amountSharesToRedeem);
        require(amountTokenOut >= minTokenOut, "SCY: insufficient out");

        _transferOut(tokenOut, receiver, amountTokenOut);

        emit Redeem(msg.sender, receiver, tokenOut, amountSharesToRedeem, amountTokenOut);
    }

    /**
     * @notice mint shares based on the deposited base tokens
     * @param tokenIn base token address used to mint shares
     * @param amountDeposited amount of base tokens deposited
     * @return amountSharesOut amount of shares minted
     */
    function _deposit(address tokenIn, uint256 amountDeposited)
        internal
        virtual
        returns (uint256 amountSharesOut);

    /**
     * @notice redeems base tokens based on amount of shares to be burned
     * @param tokenOut address of the base token to be redeemed
     * @param amountSharesToRedeem amount of shares to be burned
     * @return amountTokenOut amount of base tokens redeemed
     */
    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        virtual
        returns (uint256 amountTokenOut);

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-exchangeRate}
     */
    function exchangeRate() external view virtual override returns (uint256 res);

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-claimRewards}
     */
    function claimRewards(
        address /*user*/
    ) external virtual override returns (uint256[] memory rewardAmounts) {
        rewardAmounts = new uint256[](0);
    }

    /**
     * @dev See {ISuperComposableYield-getRewardTokens}
     */
    function getRewardTokens()
        external
        view
        virtual
        override
        returns (address[] memory rewardTokens)
    {
        rewardTokens = new address[](0);
    }

    /**
     * @dev See {ISuperComposableYield-accruredRewards}
     */
    function accruedRewards(
        address /*user*/
    ) external view virtual override returns (uint256[] memory rewardAmounts) {
        rewardAmounts = new uint256[](0);
    }

    function rewardIndexesCurrent() external virtual override returns (uint256[] memory indexes) {
        indexes = new uint256[](0);
    }

    function rewardIndexesStored()
        external
        view
        virtual
        override
        returns (uint256[] memory indexes)
    {
        indexes = new uint256[](0);
    }

    /*///////////////////////////////////////////////////////////////
                MISC METADATA FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice See {ISuperComposableYield-getBaseTokens}
     */
    function getBaseTokens() external view virtual override returns (address[] memory res);

    /**
     * @dev See {ISuperComposableYield-isValidBaseToken}
     */
    function isValidBaseToken(address token) public view virtual override returns (bool);
}
