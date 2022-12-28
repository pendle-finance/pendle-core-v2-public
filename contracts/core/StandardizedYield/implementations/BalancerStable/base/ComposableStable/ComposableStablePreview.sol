// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../../../../interfaces/Balancer/IComposableStable.sol";

import "../FixedPoint.sol";
import "./ComposableStableMath.sol";
import "../StablePoolUserData.sol";

import "../StablePreviewBase.sol";

contract ComposableStablePreview is StablePreviewBase {
    using ComposableStableMath for uint256;
    using StablePoolUserData for bytes;
    using FixedPoint for uint256;

    struct TokenRateCache {
        uint256 currentRate;
        uint256 oldRate;
    }

    address public immutable LP;

    bool public immutable noTokensExempt;
    bool public immutable allTokensExempt;
    uint256 public immutable bptIndex;
    uint256 public immutable totalTokens;

    constructor(address _LP) {
        LP = _LP;

        bytes32 POOL_ID = IBasePool(LP).getPoolId();

        bptIndex = IComposableStable(LP).getBptIndex();

        (IERC20[] memory tokens, , ) = IVault(BALANCER_VAULT).getPoolTokens(POOL_ID);

        bool anyExempt = false;
        bool anyNonExempt = false;

        // immutable vars can't be initialized inside if statements
        for (uint256 i = 0; i < tokens.length; ++i) {
            if (i == bptIndex) continue;
            if (IComposableStable(LP).isTokenExemptFromYieldProtocolFee(tokens[i])) {
                anyExempt = true;
            } else {
                anyNonExempt = true;
            }
        }

        noTokensExempt = !anyExempt;
        allTokensExempt = !anyNonExempt;
        totalTokens = tokens.length;
    }

    function onJoinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData,
        StablePoolData calldata poolData
    ) internal view override returns (uint256 bptAmountOut) {
        TokenRateCache[] memory caches = _beforeSwapJoinExit(poolData);

        uint256[] memory scalingFactors = _scalingFactors(poolData, caches);

        // skip totalSupply == 0 case

        _upscaleArray(balances, scalingFactors);
        (bptAmountOut, ) = _onJoinPool(
            poolId,
            sender,
            recipient,
            balances,
            lastChangeBlock,
            protocolSwapFeePercentage,
            scalingFactors,
            userData,
            poolData,
            caches
        );

        // skip _mintPoolTokens, _downscaleUpArray

        // we return bptAmountOut instead of minting
    }

    function onExitPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData,
        StablePoolData calldata poolData
    ) internal view override returns (uint256 amountTokenOut) {
        uint256 bptAmountIn;
        uint256[] memory amountsOut;

        // skip recovery mode

        TokenRateCache[] memory caches = _beforeSwapJoinExit(poolData);

        uint256[] memory scalingFactors = _scalingFactors(poolData, caches);
        _upscaleArray(balances, scalingFactors);

        (bptAmountIn, amountsOut) = _onExitPool(
            poolId,
            sender,
            recipient,
            balances,
            lastChangeBlock,
            protocolSwapFeePercentage, // assume no recovery mode
            scalingFactors,
            userData,
            poolData,
            caches
        );

        _downscaleDownArray(amountsOut, scalingFactors);

        // skip burnPoolTokens

        for (uint256 i = 0; i < amountsOut.length; i++) {
            if (amountsOut[i] > 0) return amountsOut[i];
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
        bytes memory userData,
        StablePoolData calldata poolData,
        TokenRateCache[] memory caches
    ) internal view returns (uint256, uint256[] memory) {
        return
            _onJoinExitPool(true, registeredBalances, scalingFactors, userData, poolData, caches);
    }

    function _onExitPool(
        bytes32,
        address,
        address,
        uint256[] memory registeredBalances,
        uint256,
        uint256,
        uint256[] memory scalingFactors,
        bytes memory userData,
        StablePoolData calldata poolData,
        TokenRateCache[] memory caches
    ) internal view returns (uint256, uint256[] memory) {
        return
            _onJoinExitPool(false, registeredBalances, scalingFactors, userData, poolData, caches);
    }

    /**
     * @return bptAmount
     * @return amountsDelta this will not contain bpt item since it will be discarded on the upper level
     */
    function _onJoinExitPool(
        bool isJoin,
        uint256[] memory registeredBalances,
        uint256[] memory scalingFactors,
        bytes memory userData,
        StablePoolData calldata poolData,
        TokenRateCache[] memory caches
    ) internal view returns (uint256 bptAmount, uint256[] memory amountsDelta) {
        (
            uint256 preJoinExitSupply,
            uint256[] memory balances,
            uint256 currentAmp,
            uint256 preJoinExitInvariant
        ) = _beforeJoinExit(registeredBalances, poolData, caches);

        function(uint256[] memory, uint256, uint256, uint256, uint256[] memory, bytes memory)
            internal
            view
            returns (uint256, uint256[] memory) _doJoinOrExit = (isJoin ? _doJoin : _doExit);

        return
            _doJoinOrExit(
                balances,
                currentAmp,
                preJoinExitSupply,
                preJoinExitInvariant,
                scalingFactors,
                userData
            );

        // skip _updateInvariantAfterJoinExit here
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
        // this is always true given Pendle SY context
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

    function _beforeJoinExit(
        uint256[] memory registeredBalances,
        StablePoolData calldata poolData,
        TokenRateCache[] memory caches
    )
        internal
        view
        returns (
            uint256,
            uint256[] memory,
            uint256,
            uint256
        )
    {
        (uint256 lastJoinExitAmp, uint256 lastPostJoinExitInvariant) = IComposableStable(LP)
            .getLastJoinExitData();

        (
            uint256 preJoinExitSupply,
            uint256[] memory balances,
            uint256 oldAmpPreJoinExitInvariant
        ) = _payProtocolFeesBeforeJoinExit(
                registeredBalances,
                lastJoinExitAmp,
                lastPostJoinExitInvariant,
                poolData,
                caches
            );

        (uint256 currentAmp, , ) = IComposableStable(LP).getAmplificationParameter();
        uint256 preJoinExitInvariant = currentAmp == lastJoinExitAmp
            ? oldAmpPreJoinExitInvariant
            : currentAmp._calculateInvariant(balances);

        return (preJoinExitSupply, balances, currentAmp, preJoinExitInvariant);
    }

    function _payProtocolFeesBeforeJoinExit(
        uint256[] memory registeredBalances,
        uint256 lastJoinExitAmp,
        uint256 lastPostJoinExitInvariant,
        StablePoolData calldata poolData,
        TokenRateCache[] memory caches
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
                lastPostJoinExitInvariant,
                poolData,
                caches
            );

        uint256 protocolFeeAmount = _calculateAdjustedProtocolFeeAmount(
            virtualSupply,
            expectedProtocolOwnershipPercentage
        );

        // skip _payProtocolFee, which will make the LP balance from this point onwards to be off

        return (virtualSupply + protocolFeeAmount, balances, currentInvariantWithLastJoinExitAmp);
    }

    function _getProtocolPoolOwnershipPercentage(
        uint256[] memory balances,
        uint256 lastJoinExitAmp,
        uint256 lastPostJoinExitInvariant,
        StablePoolData calldata poolData,
        TokenRateCache[] memory caches
    ) internal view returns (uint256, uint256) {
        (
            uint256 swapFeeGrowthInvariant,
            uint256 totalNonExemptGrowthInvariant,
            uint256 totalGrowthInvariant
        ) = _getGrowthInvariants(balances, lastJoinExitAmp, poolData, caches);

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
                IComposableStable(LP).getProtocolFeePercentageCache(0) // ProtocolFeeType.SWAP // can't get better
            );

        uint256 protocolYieldPercentage = nonExemptYieldGrowthInvariantDelta
            .divDown(totalGrowthInvariant)
            .mulDown(
                IComposableStable(LP).getProtocolFeePercentageCache(2) // ProtocolFeeType.YIELD // can't get better
            );

        // These percentages can then be simply added to compute the total protocol Pool ownership percentage.
        // This is naturally bounded above by FixedPoint.ONE so this addition cannot overflow.
        return (protocolSwapFeePercentage + protocolYieldPercentage, totalGrowthInvariant);
    }

    function _getGrowthInvariants(
        uint256[] memory balances,
        uint256 lastJoinExitAmp,
        StablePoolData calldata poolData,
        TokenRateCache[] memory caches
    )
        internal
        view
        returns (
            uint256 swapFeeGrowthInvariant,
            uint256 totalNonExemptGrowthInvariant,
            uint256 totalGrowthInvariant
        )
    {
        swapFeeGrowthInvariant = lastJoinExitAmp._calculateInvariant(
            _getAdjustedBalances(balances, true, poolData, caches)
        );

        if (noTokensExempt) {
            totalNonExemptGrowthInvariant = lastJoinExitAmp._calculateInvariant(balances);
            totalGrowthInvariant = totalNonExemptGrowthInvariant;
        } else if (allTokensExempt) {
            totalNonExemptGrowthInvariant = swapFeeGrowthInvariant;
            totalGrowthInvariant = lastJoinExitAmp._calculateInvariant(balances);
        } else {
            totalNonExemptGrowthInvariant = lastJoinExitAmp._calculateInvariant(
                _getAdjustedBalances(balances, false, poolData, caches)
            );

            totalGrowthInvariant = lastJoinExitAmp._calculateInvariant(balances);
        }
    }

    function _getAdjustedBalances(
        uint256[] memory balances,
        bool ignoreExemptFlags,
        StablePoolData calldata poolData,
        TokenRateCache[] memory tokenRateCaches
    ) internal view returns (uint256[] memory) {
        uint256 totalTokensWithoutBpt = balances.length;
        uint256[] memory adjustedBalances = new uint256[](totalTokensWithoutBpt);

        for (uint256 i = 0; i < totalTokensWithoutBpt; ++i) {
            uint256 skipBptIndex = i >= bptIndex ? i + 1 : i;
            adjustedBalances[i] = _isTokenExemptFromYieldProtocolFee(poolData, skipBptIndex) ||
                (ignoreExemptFlags && _hasRateProvider(poolData, skipBptIndex))
                ? _adjustedBalance(balances[i], tokenRateCaches[skipBptIndex])
                : balances[i];
        }

        return adjustedBalances;
    }

    function _adjustedBalance(uint256 balance, TokenRateCache memory cache)
        private
        pure
        returns (uint256)
    {
        return (balance * cache.oldRate) / cache.currentRate;
    }

    function _calculateAdjustedProtocolFeeAmount(uint256 supply, uint256 basePercentage)
        internal
        pure
        returns (uint256)
    {
        return supply.mulDown(basePercentage).divDown(basePercentage.complement());
    }

    function _dropBptItemFromBalances(uint256[] memory registeredBalances)
        internal
        view
        returns (uint256, uint256[] memory)
    {
        return (_getVirtualSupply(registeredBalances[bptIndex]), _dropBptItem(registeredBalances));
    }

    function _dropBptItem(uint256[] memory amounts) internal view returns (uint256[] memory) {
        uint256[] memory amountsWithoutBpt = new uint256[](amounts.length - 1);
        for (uint256 i = 0; i < amountsWithoutBpt.length; i++) {
            amountsWithoutBpt[i] = amounts[i < bptIndex ? i : i + 1];
        }

        return amountsWithoutBpt;
    }

    function _getVirtualSupply(uint256 bptBalance) internal view returns (uint256) {
        return (IERC20(LP).totalSupply()).sub(bptBalance); // can't get better
    }

    function _beforeSwapJoinExit(StablePoolData calldata poolData)
        internal
        view
        returns (TokenRateCache[] memory tokenRateCaches)
    {
        return _cacheTokenRatesIfNecessary(poolData);
    }

    function _cacheTokenRatesIfNecessary(StablePoolData calldata poolData)
        internal
        view
        returns (TokenRateCache[] memory tokenRateCaches)
    {
        tokenRateCaches = new TokenRateCache[](totalTokens);

        for (uint256 i = 0; i < totalTokens; ++i) {
            tokenRateCaches[i] = _cacheTokenRateIfNecessary(i, poolData);
        }
    }

    /**
     * @dev Caches the rate for a token if necessary. It ignores the call if there is no provider set.
     */
    function _cacheTokenRateIfNecessary(uint256 index, StablePoolData calldata poolData)
        internal
        view
        returns (TokenRateCache memory res)
    {
        if (index == bptIndex || !_hasRateProvider(poolData, index)) return res;

        uint256 expires;
        (res.currentRate, res.oldRate, , expires) = IComposableStable(LP).getTokenRateCache(
            IERC20(poolData.poolTokens[index])
        );

        if (block.timestamp > expires) {
            res.currentRate = IRateProvider(poolData.rateProviders[index]).getRate();
        }
    }

    function _scalingFactors(StablePoolData calldata poolData, TokenRateCache[] memory caches)
        internal
        view
        virtual
        returns (uint256[] memory)
    {
        // There is no need to check the arrays length since both are based on `_getTotalTokens`
        uint256[] memory scalingFactors = new uint256[](totalTokens);

        for (uint256 i = 0; i < totalTokens; ++i) {
            scalingFactors[i] = poolData.rawScalingFactors[i].mulDown(_getTokenRate(caches, i));
        }

        return scalingFactors;
    }

    function _getTokenRate(TokenRateCache[] memory caches, uint256 index)
        internal
        view
        virtual
        returns (uint256)
    {
        return caches[index].currentRate == 0 ? FixedPoint.ONE : caches[index].currentRate;
    }

    /*///////////////////////////////////////////////////////////////
                               Helpers functions
    //////////////////////////////////////////////////////////////*/

    function _upscaleArray(uint256[] memory amounts, uint256[] memory scalingFactors)
        internal
        pure
    {
        uint256 length = amounts.length;
        for (uint256 i = 0; i < length; ++i) {
            amounts[i] = FixedPoint.mulDown(amounts[i], scalingFactors[i]);
        }
    }

    function _downscaleDownArray(uint256[] memory amounts, uint256[] memory scalingFactors)
        internal
        pure
    {
        uint256 length = amounts.length;
        for (uint256 i = 0; i < length; ++i) {
            amounts[i] = FixedPoint.divDown(amounts[i], scalingFactors[i]);
        }
    }
}
