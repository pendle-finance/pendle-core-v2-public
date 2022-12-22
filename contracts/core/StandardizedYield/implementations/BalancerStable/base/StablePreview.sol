// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../library/FixedPoint.sol";
import "../library/StableMath.sol";
import "../library/StablePoolUserData.sol";
import "../library/BasePoolUserData.sol";
import "./VaultPreview.sol";
import "../../../../../interfaces/Balancer/IBasePool.sol";
import "../../../../../interfaces/Balancer/IVault.sol";
import "../../../../../interfaces/Balancer/IBalancerFees.sol";
import "./VaultPreview.sol";

contract StablePreview is VaultPreview {
    using FixedPoint for uint256;
    using StableMath for uint256;
    using StablePoolUserData for bytes;
    using BasePoolUserData for bytes;

    address public immutable LP;
    bytes32 public immutable POOL_ID;

    constructor(address _LP, bytes32 _POOL_ID) {
        LP = _LP;
        POOL_ID = _POOL_ID;
    }

    function onJoinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) internal view override returns (uint256 bptAmountOut) {
        (bool paused, , ) = IBasePool(LP).getPausedState();
        require(!paused, "Pool is paused");

        uint256[] memory scalingFactors = IBasePool(LP).getScalingFactors();
        _upscaleArray(balances, scalingFactors);

        (bptAmountOut, ) = _onJoinPool(
            poolId,
            sender,
            recipient,
            balances,
            lastChangeBlock,
            IBasePool(LP).inRecoveryMode() ? 0 : protocolSwapFeePercentage,
            scalingFactors,
            userData
        );
    }

    function onExitPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) internal view override returns (uint256 amountTokenOut) {
        uint256 bptAmountIn;
        uint256[] memory amountsOut;

        if (userData.isRecoveryModeExitKind()) {
            require(IBasePool(LP).inRecoveryMode(), "Only recovery mode");
            (bptAmountIn, amountsOut) = _doRecoveryModeExit(
                balances,
                IERC20(LP).totalSupply(),
                userData
            );
        } else {
            bool paused;
            (paused, , ) = IBasePool(LP).getPausedState();
            require(!paused, "Pool is paused");

            uint256[] memory scalingFactors = IBasePool(LP).getScalingFactors();
            _upscaleArray(balances, scalingFactors);

            (bptAmountIn, amountsOut) = _onExitPool(
                poolId,
                sender,
                recipient,
                balances,
                lastChangeBlock,
                IBasePool(LP).inRecoveryMode() ? 0 : protocolSwapFeePercentage,
                scalingFactors,
                userData
            );

            _downscaleDownArray(amountsOut, scalingFactors);
        }

        for (uint256 i = 0; i < amountsOut.length; i++) {
            if (amountsOut[i] > 0) {
                amountTokenOut = amountsOut[i];
            }
        }
    }

    function _doRecoveryModeExit(
        uint256[] memory registeredBalances,
        uint256,
        bytes memory userData
    ) internal view returns (uint256, uint256[] memory) {
        (uint256 virtualSupply, uint256[] memory balances) = _dropBptItemFromBalances(
            registeredBalances
        );

        uint256 bptAmountIn = userData.recoveryModeExit();
        uint256[] memory amountsOut = _computeProportionalAmountsOut(
            balances,
            virtualSupply,
            bptAmountIn
        );

        return (bptAmountIn, _addBptItem(amountsOut, 0));
    }

    function _computeProportionalAmountsOut(
        uint256[] memory balances,
        uint256 totalSupply,
        uint256 bptAmountIn
    ) internal pure returns (uint256[] memory amountsOut) {
        uint256 bptRatio = bptAmountIn.divDown(totalSupply);

        amountsOut = new uint256[](balances.length);
        for (uint256 i = 0; i < balances.length; i++) {
            amountsOut[i] = balances[i].mulDown(bptRatio);
        }
    }

    function _addBptItem(uint256[] memory amounts, uint256 bptAmount)
        internal
        view
        returns (uint256[] memory registeredTokenAmounts)
    {
        registeredTokenAmounts = new uint256[](amounts.length + 1);
        for (uint256 i = 0; i < registeredTokenAmounts.length; i++) {
            registeredTokenAmounts[i] = i == IBasePool(LP).getBptIndex()
                ? bptAmount
                : amounts[i < IBasePool(LP).getBptIndex() ? i : i - 1];
        }
    }

    function _onJoinPool(
        bytes32,
        address,
        address,
        uint256[] memory registeredBalances,
        uint256,
        uint256,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal view returns (uint256, uint256[] memory) {
        return _onJoinExitPool(true, registeredBalances, scalingFactors, userData);
    }

    function _onExitPool(
        bytes32,
        address,
        address,
        uint256[] memory registeredBalances,
        uint256,
        uint256,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal view returns (uint256, uint256[] memory) {
        return _onJoinExitPool(false, registeredBalances, scalingFactors, userData);
    }

    function _onJoinExitPool(
        bool isJoin,
        uint256[] memory registeredBalances,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal view returns (uint256 bptAmount, uint256[] memory amountsDelta) {
        (
            uint256 preJoinExitSupply,
            uint256[] memory balances,
            uint256 currentAmp,
            uint256 preJoinExitInvariant
        ) = _beforeJoinExit(registeredBalances);

        function(uint256[] memory, uint256, uint256, uint256, uint256[] memory, bytes memory)
            internal
            view
            returns (uint256, uint256[] memory) _doJoinOrExit = (isJoin ? _doJoin : _doExit);

        (bptAmount, amountsDelta) = _doJoinOrExit(
            balances,
            currentAmp,
            preJoinExitSupply,
            preJoinExitInvariant,
            scalingFactors,
            userData
        );
    }

    function _doJoin(
        uint256[] memory balances,
        uint256 currentAmp,
        uint256 preJoinExitSupply,
        uint256 preJoinExitInvariant,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal view returns (uint256, uint256[] memory) {
        // this is always true given Pendle SY context
        // if (kind == StablePoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT)
        return
            _joinExactTokensInForBPTOut(
                preJoinExitSupply,
                preJoinExitInvariant,
                currentAmp,
                balances,
                scalingFactors,
                userData
            );
    }

    function _joinExactTokensInForBPTOut(
        uint256 actualSupply,
        uint256 preJoinExitInvariant,
        uint256 currentAmp,
        uint256[] memory balances,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) private view returns (uint256, uint256[] memory) {
        (uint256[] memory amountsIn, ) = userData.exactTokensInForBptOut();

        // The user-provided amountsIn is unscaled, so we address that.
        _upscaleArray(amountsIn, _dropBptItem(scalingFactors));

        uint256 bptAmountOut = currentAmp._calcBptOutGivenExactTokensIn(
            balances,
            amountsIn,
            actualSupply,
            preJoinExitInvariant,
            IBasePool(LP).getSwapFeePercentage()
        );
        return (bptAmountOut, amountsIn);
    }

    function _doExit(
        uint256[] memory balances,
        uint256 currentAmp,
        uint256 preJoinExitSupply,
        uint256 preJoinExitInvariant,
        uint256[] memory, /*scalingFactors*/
        bytes memory userData
    ) internal view returns (uint256, uint256[] memory) {
        //if (kind == StablePoolUserData.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT)
        return
            _exitExactBPTInForTokenOut(
                preJoinExitSupply,
                preJoinExitInvariant,
                currentAmp,
                balances,
                userData
            );
    }

    function _exitExactBPTInForTokenOut(
        uint256 actualSupply,
        uint256 preJoinExitInvariant,
        uint256 currentAmp,
        uint256[] memory balances,
        bytes memory userData
    ) private view returns (uint256, uint256[] memory) {
        (uint256 bptAmountIn, uint256 tokenIndex) = userData.exactBptInForTokenOut();

        uint256[] memory amountsOut = new uint256[](balances.length);

        amountsOut[tokenIndex] = currentAmp._calcTokenOutGivenExactBptIn(
            balances,
            tokenIndex,
            bptAmountIn,
            actualSupply,
            preJoinExitInvariant,
            IBasePool(LP).getSwapFeePercentage()
        );

        return (bptAmountIn, amountsOut);
    }

    function _upscaleArray(uint256[] memory amounts, uint256[] memory scalingFactors)
        internal
        pure
    {
        require(amounts.length == scalingFactors.length, "Array length mismatch");

        uint256 length = amounts.length;
        for (uint256 i = 0; i < length; ++i) {
            amounts[i] = FixedPoint.mulDown(amounts[i], scalingFactors[i]);
        }
    }

    function _downscaleDownArray(uint256[] memory amounts, uint256[] memory scalingFactors)
        internal
        pure
    {
        require(amounts.length == scalingFactors.length, "Array length mismatch");

        uint256 length = amounts.length;
        for (uint256 i = 0; i < length; ++i) {
            amounts[i] = FixedPoint.divDown(amounts[i], scalingFactors[i]);
        }
    }

    function _beforeJoinExit(uint256[] memory registeredBalances)
        internal
        view
        returns (
            uint256,
            uint256[] memory,
            uint256,
            uint256
        )
    {
        (uint256 lastJoinExitAmp, uint256 lastPostJoinExitInvariant) = IBasePool(LP)
            .getLastJoinExitData();

        (
            uint256 preJoinExitSupply,
            uint256[] memory balances,
            uint256 oldAmpPreJoinExitInvariant
        ) = _payProtocolFeesBeforeJoinExit(
                registeredBalances,
                lastJoinExitAmp,
                lastPostJoinExitInvariant
            );

        (uint256 currentAmp, , ) = IBasePool(LP).getAmplificationParameter();
        uint256 preJoinExitInvariant = currentAmp == lastJoinExitAmp
            ? oldAmpPreJoinExitInvariant
            : currentAmp._calculateInvariant(balances);

        return (preJoinExitSupply, balances, currentAmp, preJoinExitInvariant);
    }

    function _payProtocolFeesBeforeJoinExit(
        uint256[] memory registeredBalances,
        uint256 lastJoinExitAmp,
        uint256 lastPostJoinExitInvariant
    )
        internal
        view
        returns (
            uint256,
            uint256[] memory,
            uint256
        )
    {
        (uint256 virtualSupply, uint256[] memory balances) = _dropBptItemFromBalances(
            registeredBalances
        );

        (
            uint256 expectedProtocolOwnershipPercentage,
            uint256 currentInvariantWithLastJoinExitAmp
        ) = _getProtocolPoolOwnershipPercentage(
                balances,
                lastJoinExitAmp,
                lastPostJoinExitInvariant
            );

        uint256 protocolFeeAmount = _calculateAdjustedProtocolFeeAmount(
            virtualSupply,
            expectedProtocolOwnershipPercentage
        );

        return (virtualSupply + protocolFeeAmount, balances, currentInvariantWithLastJoinExitAmp);
    }

    function _calculateAdjustedProtocolFeeAmount(uint256 supply, uint256 basePercentage)
        internal
        pure
        returns (uint256)
    {
        return supply.mulDown(basePercentage).divDown(basePercentage.complement());
    }

    function _getProtocolPoolOwnershipPercentage(
        uint256[] memory balances,
        uint256 lastJoinExitAmp,
        uint256 lastPostJoinExitInvariant
    ) internal view returns (uint256, uint256) {
        (
            uint256 swapFeeGrowthInvariant,
            uint256 totalNonExemptGrowthInvariant,
            uint256 totalGrowthInvariant
        ) = _getGrowthInvariants(balances, lastJoinExitAmp);

        uint256 swapFeeGrowthInvariantDelta = (swapFeeGrowthInvariant > lastPostJoinExitInvariant)
            ? swapFeeGrowthInvariant - lastPostJoinExitInvariant
            : 0;
        uint256 nonExemptYieldGrowthInvariantDelta = (totalNonExemptGrowthInvariant >
            swapFeeGrowthInvariant)
            ? totalNonExemptGrowthInvariant - swapFeeGrowthInvariant
            : 0;

        uint256 protocolSwapFeePercentage = swapFeeGrowthInvariantDelta
            .divDown(totalGrowthInvariant)
            .mulDown(
                IBasePool(LP).getProtocolFeePercentageCache(0) // ProtocolFeeType.SWAP
            );

        uint256 protocolYieldPercentage = nonExemptYieldGrowthInvariantDelta
            .divDown(totalGrowthInvariant)
            .mulDown(
                IBasePool(LP).getProtocolFeePercentageCache(2) // ProtocolFeeType.YIELD
            );

        // These percentages can then be simply added to compute the total protocol Pool ownership percentage.
        // This is naturally bounded above by FixedPoint.ONE so this addition cannot overflow.
        return (protocolSwapFeePercentage + protocolYieldPercentage, totalGrowthInvariant);
    }

    function _getGrowthInvariants(uint256[] memory balances, uint256 lastJoinExitAmp)
        internal
        view
        returns (
            uint256 swapFeeGrowthInvariant,
            uint256 totalNonExemptGrowthInvariant,
            uint256 totalGrowthInvariant
        )
    {
        swapFeeGrowthInvariant = lastJoinExitAmp._calculateInvariant(
            _getAdjustedBalances(balances, true)
        );

        if (_areNoTokensExempt()) {
            totalNonExemptGrowthInvariant = lastJoinExitAmp._calculateInvariant(balances);
            totalGrowthInvariant = totalNonExemptGrowthInvariant;
        } else if (_areAllTokensExempt()) {
            totalNonExemptGrowthInvariant = swapFeeGrowthInvariant;
            totalGrowthInvariant = lastJoinExitAmp._calculateInvariant(balances);
        } else {
            totalNonExemptGrowthInvariant = lastJoinExitAmp._calculateInvariant(
                _getAdjustedBalances(balances, false)
            );

            totalGrowthInvariant = lastJoinExitAmp._calculateInvariant(balances);
        }
    }

    function _areNoTokensExempt() internal view returns (bool) {
        (IERC20[] memory tokens, , ) = IVault(BALANCER_VAULT).getPoolTokens(POOL_ID);
        for (uint256 i = 0; i < tokens.length; i++) {
            if (IBasePool(LP).isTokenExemptFromYieldProtocolFee(tokens[i])) {
                return false;
            }
        }
        return true;
    }

    function _areAllTokensExempt() internal view returns (bool) {
        (IERC20[] memory tokens, , ) = IVault(BALANCER_VAULT).getPoolTokens(POOL_ID);
        for (uint256 i = 0; i < tokens.length; i++) {
            if (!IBasePool(LP).isTokenExemptFromYieldProtocolFee(tokens[i])) {
                return false;
            }
        }
        return true;
    }

    function _getAdjustedBalances(uint256[] memory balances, bool ignoreExemptFlags)
        internal
        view
        returns (uint256[] memory)
    {
        uint256 totalTokensWithoutBpt = balances.length;
        uint256[] memory adjustedBalances = new uint256[](totalTokensWithoutBpt);

        for (uint256 i = 0; i < totalTokensWithoutBpt; ++i) {
            uint256 skipBptIndex = i >= IBasePool(LP).getBptIndex() ? i + 1 : i;
            adjustedBalances[i] = _isTokenExemptFromYieldProtocolFee(skipBptIndex) ||
                (ignoreExemptFlags && _hasRateProvider(skipBptIndex))
                ? _adjustedBalance(balances[i], skipBptIndex)
                : balances[i];
        }

        return adjustedBalances;
    }

    function _adjustedBalance(uint256 balance, uint256 registeredTokenIndex)
        private
        view
        returns (uint256)
    {
        (IERC20[] memory tokens, , ) = IVault(BALANCER_VAULT).getPoolTokens(POOL_ID);

        (uint256 currentRate, uint256 oldRate, , ) = IBasePool(LP).getTokenRateCache(
            tokens[registeredTokenIndex]
        );
        return (balance * oldRate) / currentRate;
    }

    function _hasRateProvider(uint256 registeredTokenIndex) internal view returns (bool) {
        address[] memory rateProviders = IBasePool(LP).getRateProviders();
        return rateProviders[registeredTokenIndex] != address(0);
    }

    function _isTokenExemptFromYieldProtocolFee(uint256 registeredTokenIndex)
        internal
        view
        returns (bool)
    {
        (IERC20[] memory tokens, , ) = IVault(BALANCER_VAULT).getPoolTokens(POOL_ID);
        return IBasePool(LP).isTokenExemptFromYieldProtocolFee(tokens[registeredTokenIndex]);
    }

    function _dropBptItemFromBalances(uint256[] memory registeredBalances)
        internal
        view
        returns (uint256, uint256[] memory)
    {
        return (
            _getVirtualSupply(registeredBalances[IBasePool(LP).getBptIndex()]),
            _dropBptItem(registeredBalances)
        );
    }

    function _dropBptItem(uint256[] memory amounts) internal view returns (uint256[] memory) {
        uint256[] memory amountsWithoutBpt = new uint256[](amounts.length - 1);
        for (uint256 i = 0; i < amountsWithoutBpt.length; i++) {
            amountsWithoutBpt[i] = amounts[i < IBasePool(LP).getBptIndex() ? i : i + 1];
        }

        return amountsWithoutBpt;
    }

    function _getVirtualSupply(uint256 bptBalance) internal view returns (uint256) {
        return (IERC20(LP).totalSupply()).sub(bptBalance);
    }
}
