// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./PendleConvexCurveLPSCY.sol";

contract PendleConvexCurveLP2PoolSCY is PendleConvexCurveLPSCY {
    address public immutable token1;
    address public immutable token2;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _pid,
        address _convexBooster,
        address _crvLpToken,
        address _cvx,
        address _baseCrvPool,
        address[] memory _basePoolTokens
    )
        PendleConvexCurveLPSCY(
            _name,
            _symbol,
            _pid,
            _convexBooster,
            _crvLpToken,
            _cvx,
            _baseCrvPool
        )
    {
        if (_basePoolTokens.length != 2) revert Errors.ArrayLengthMismatch();

        token1 = _basePoolTokens[0];
        token2 = _basePoolTokens[1];

        _safeApprove(token1, crvPool, type(uint256).max);
        _safeApprove(token2, crvPool, type(uint256).max);
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](3);
        res[0] = LP;
        res[1] = token1;
        res[2] = token2;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](3);
        res[0] = LP;
        res[1] = token1;
        res[2] = token2;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool res) {
        res = (token == LP || token == token1 || token == token2);
    }

    function isValidTokenOut(address token) public view virtual override returns (bool res) {
        res = (token == LP || token == token1 || token == token2);
    }

    function _getBaseTokenIndex(address crvBaseToken)
        internal
        view
        virtual
        override
        returns (uint256 index)
    {
        if (crvBaseToken == token1) {
            index = 0;
        } else {
            index = 1;
        }
    }

    function _isBaseToken(address token) internal view virtual override returns (bool res) {
        return (token == token1 || token == token2);
    }

    function _depositToCurve(address token, uint256 amount) internal virtual override {
        uint256[2] memory amounts;
        amounts[_getBaseTokenIndex(token)] = amount;
        ICrvPool(crvPool).add_liquidity(amounts, 0);
    }

    function _previewDepositToCurve(address token, uint256 amount)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        uint256[2] memory amounts;
        amounts[_getBaseTokenIndex(token)] = amount;
        return ICrvPool(crvPool).calc_token_amount(amounts, true);
    }
}
