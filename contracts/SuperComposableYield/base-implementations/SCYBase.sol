// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "../../interfaces/ISuperComposableYield.sol";
import "./RewardManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../../libraries/math/Math.sol";
import "../../libraries/SCY/SCYUtils.sol";
import "../../libraries/helpers/TokenHelper.sol";
import "../../../contracts/core/PendleERC20.sol";

abstract contract SCYBase is ISuperComposableYield, PendleERC20, TokenHelper {
    using Math for uint256;

    address public immutable yieldToken;

    uint256 public yieldTokenReserve;

    modifier updateYieldReserve() {
        _;
        _updateYieldReserve();
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _yieldToken
    ) PendleERC20(_name, _symbol, 18) {
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
        uint256 amountTokenToPull,
        uint256 minSharesOut
    ) external payable nonReentrant updateYieldReserve returns (uint256 amountSharesOut) {
        require(isValidBaseToken(tokenIn), "SCY: Invalid tokenIn");

        if (tokenIn == NATIVE) require(amountTokenToPull == 0, "can't pull eth");
        else if (amountTokenToPull != 0) _transferIn(tokenIn, msg.sender, amountTokenToPull);

        uint256 amountDeposited = _getFloatingAmount(tokenIn);

        amountSharesOut = _deposit(tokenIn, amountDeposited);
        require(amountSharesOut >= minSharesOut, "insufficient out");

        _mint(receiver, amountSharesOut);
        emit Deposit(msg.sender, receiver, tokenIn, amountDeposited, amountSharesOut);
    }

    /**
     * @dev See {ISuperComposableYield-redeem}
     */
    function redeem(
        address receiver,
        uint256 amountSharesToPull,
        address tokenOut,
        uint256 minTokenOut
    ) external nonReentrant updateYieldReserve returns (uint256 amountTokenOut) {
        require(isValidBaseToken(tokenOut), "SCY: invalid tokenOut");

        if (amountSharesToPull != 0) {
            _spendAllowance(msg.sender, address(this), amountSharesToPull);
            _transfer(msg.sender, address(this), amountSharesToPull);
        }

        uint256 amountSharesToRedeem = _getFloatingAmount(address(this));

        amountTokenOut = _redeem(tokenOut, amountSharesToRedeem);
        require(amountTokenOut >= minTokenOut, "insufficient out");

        _burn(address(this), amountSharesToRedeem);
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

    /**
     * @notice updates the amount of yield token reserves in this contract
     */
    function _updateYieldReserve() internal virtual {
        yieldTokenReserve = _selfBalance(yieldToken);
    }

    /**
     * @notice returns the amount of unprocessed tokens owned by this contract
     * @param token address of the token to be queried
     */
    function _getFloatingAmount(address token) internal view virtual returns (uint256) {
        if (token != yieldToken) return _selfBalance(token);
        return _selfBalance(token) - yieldTokenReserve;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-exchangeRateCurrent}
     */
    function exchangeRateCurrent() external virtual override returns (uint256 res);

    /**
     * @dev See {ISuperComposableYield-exchangeRateStored}
     */
    function exchangeRateStored() external view virtual override returns (uint256 res);

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
