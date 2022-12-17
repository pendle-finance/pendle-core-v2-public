// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FixedPoint.sol";
import "./StableMath.sol";
import "./StablePoolUserData.sol";
import "./BasePoolUserData.sol";
import "../../../../../interfaces/Balancer/IBasePool.sol";
import "../../../../../interfaces/Balancer/IVault.sol";
import "../../../../../interfaces/Balancer/IBalancerFees.sol";

/**
 * @dev Fork of Balancer WStEth-REth-SFrxEth pool, for SY preview deposit/redeems
 * Given that this is only for view functions, this library disregards most gas optimizations
 */

library Balancer3EthPoolHelper {
    using FixedPoint for uint256;
    using StablePoolUserData for bytes;
    using BasePoolUserData for bytes;

    address internal constant LP = 0x8e85e97ed19C0fa13B2549309965291fbbc0048b;
    address internal constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    bytes32 internal constant POOL_ID =
        0x8e85e97ed19c0fa13b2549309965291fbbc0048b0000000000000000000003ba;

    /*///////////////////////////////////////////////////////////////
                               VAULT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    struct PoolBalanceChange {
        IAsset[] assets;
        uint256[] limits;
        bytes userData;
        bool useInternalBalance;
    }

    function joinPoolPreview(
        bytes32 poolId,
        address sender,
        address recipient,
        IVault.JoinPoolRequest memory request
    ) internal view returns (uint256 amountBptOut) {
        (bool paused, , ) = IBasePool(LP).getPausedState();
        require(!paused, "Pool is paused");

        amountBptOut = _joinOrExit(0, poolId, sender, recipient, _toPoolBalanceChange(request));
    }

    function exitPoolPreview(
        bytes32 poolId,
        address sender,
        address recipient,
        IVault.ExitPoolRequest memory request
    ) internal view returns (uint256 amountTokenOut) {
        amountTokenOut = _joinOrExit(1, poolId, sender, recipient, _toPoolBalanceChange(request));
    }

    function _joinOrExit(
        uint256 kind,
        bytes32 poolId,
        address sender,
        address recipient,
        PoolBalanceChange memory change
    ) private view returns (uint256 amountBptOrTokensOut) {
        require(change.assets.length == change.limits.length, "Input length mismatch");

        IERC20[] memory tokens = _translateToIERC20(change.assets);
        (uint256[] memory balances, uint256 lastChangeBlock) = _validateTokensAndGetBalances(
            poolId,
            tokens
        );

        amountBptOrTokensOut = _callPoolBalanceChange(
            kind,
            poolId,
            sender,
            recipient,
            change,
            balances,
            lastChangeBlock
        );
    }

    function _callPoolBalanceChange(
        uint256 kind,
        bytes32 poolId,
        address sender,
        address recipient,
        PoolBalanceChange memory change,
        uint256[] memory balances,
        uint256 lastChangeBlock
    ) private view returns (uint256 amountsChanged) {
        if (kind == 0) {
            amountsChanged = onJoinPoolPreview(
                poolId,
                sender,
                recipient,
                balances,
                lastChangeBlock,
                _getProtocolSwapFeePercentage(),
                change.userData
            );
        } else {
            amountsChanged = onExitPoolPreview(
                poolId,
                sender,
                recipient,
                balances,
                lastChangeBlock,
                _getProtocolSwapFeePercentage(),
                change.userData
            );
        }
    }

    function _getProtocolSwapFeePercentage() private view returns (uint256) {
        address collector = IVault(BALANCER_VAULT).getProtocolFeesCollector();
        return IBalancerFees(collector).getSwapFeePercentage();
    }

    function _validateTokensAndGetBalances(
        bytes32 poolId,
        IERC20[] memory expectedTokens
    ) private view returns (uint256[] memory, uint256) {
        (
            IERC20[] memory actualTokens,
            uint256[] memory balances,
            uint256 lastChangeBlock
        ) = IVault(BALANCER_VAULT).getPoolTokens(poolId);
        require(actualTokens.length == expectedTokens.length, "Array length mismatch");
        require(actualTokens.length > 0, "Pool is empty");

        for (uint256 i = 0; i < actualTokens.length; ++i) {
            require(actualTokens[i] == expectedTokens[i], "Tokens mismatch");
        }
        return (balances, lastChangeBlock);
    }

    function _translateToIERC20(IAsset[] memory assets) internal view returns (IERC20[] memory) {
        IERC20[] memory tokens = new IERC20[](assets.length);
        for (uint256 i = 0; i < assets.length; ++i) {
            tokens[i] = _translateToIERC20(assets[i]);
        }
        return tokens;
    }

    function _translateToIERC20(IAsset asset) internal view returns (IERC20) {
        return
            address(asset) == address(0) ? IVault(BALANCER_VAULT).WETH() : IERC20(address(asset));
    }

    function _toPoolBalanceChange(
        IVault.JoinPoolRequest memory request
    ) private pure returns (PoolBalanceChange memory change) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            change := request
        }
    }

    function _toPoolBalanceChange(
        IVault.ExitPoolRequest memory request
    ) private pure returns (PoolBalanceChange memory change) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            change := request
        }
    }

    /*///////////////////////////////////////////////////////////////
                               POOL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function onJoinPoolPreview(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) internal view returns (uint256 bptAmountOut) {
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

    function onExitPoolPreview(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) internal view returns (uint256 amountTokenOut) {
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
                IBasePool(LP).inRecoveryMode() ? 0 : protocolSwapFeePercentage, // Protocol fees are disabled while in recovery mode
                scalingFactors,
                userData
            );

            // amountsOut are amounts exiting the Pool, so we round down.
            _downscaleDownArray(amountsOut, scalingFactors);
        }

        for (uint i = 0; i < amountsOut.length; i++) {
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

    function _addBptItem(
        uint256[] memory amounts,
        uint256 bptAmount
    ) internal view returns (uint256[] memory registeredTokenAmounts) {
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

        uint256 bptAmountOut = StableMath._calcBptOutGivenExactTokensIn(
            currentAmp,
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
        uint256[] memory /*scalingFactors*/,
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

        amountsOut[tokenIndex] = StableMath._calcTokenOutGivenExactBptIn(
            currentAmp,
            balances,
            tokenIndex,
            bptAmountIn,
            actualSupply,
            preJoinExitInvariant,
            IBasePool(LP).getSwapFeePercentage()
        );

        return (bptAmountIn, amountsOut);
    }

    function _upscaleArray(
        uint256[] memory amounts,
        uint256[] memory scalingFactors
    ) internal pure {
        require(amounts.length == scalingFactors.length, "Array length mismatch");

        uint256 length = amounts.length;
        for (uint256 i = 0; i < length; ++i) {
            amounts[i] = FixedPoint.mulDown(amounts[i], scalingFactors[i]);
        }
    }

    function _downscaleDownArray(
        uint256[] memory amounts,
        uint256[] memory scalingFactors
    ) internal pure {
        require(amounts.length == scalingFactors.length, "Array length mismatch");

        uint256 length = amounts.length;
        for (uint256 i = 0; i < length; ++i) {
            amounts[i] = FixedPoint.divDown(amounts[i], scalingFactors[i]);
        }
    }

    function _beforeJoinExit(
        uint256[] memory registeredBalances
    ) internal view returns (uint256, uint256[] memory, uint256, uint256) {
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
            : StableMath._calculateInvariant(currentAmp, balances);

        return (preJoinExitSupply, balances, currentAmp, preJoinExitInvariant);
    }

    function _payProtocolFeesBeforeJoinExit(
        uint256[] memory registeredBalances,
        uint256 lastJoinExitAmp,
        uint256 lastPostJoinExitInvariant
    ) internal view returns (uint256, uint256[] memory, uint256) {
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

    function _calculateAdjustedProtocolFeeAmount(
        uint256 supply,
        uint256 basePercentage
    ) internal pure returns (uint256) {
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

    function _getGrowthInvariants(
        uint256[] memory balances,
        uint256 lastJoinExitAmp
    )
        internal
        view
        returns (
            uint256 swapFeeGrowthInvariant,
            uint256 totalNonExemptGrowthInvariant,
            uint256 totalGrowthInvariant
        )
    {
        swapFeeGrowthInvariant = StableMath._calculateInvariant(
            lastJoinExitAmp,
            _getAdjustedBalances(balances, true)
        );

        if (_areNoTokensExempt()) {
            totalNonExemptGrowthInvariant = StableMath._calculateInvariant(
                lastJoinExitAmp,
                balances
            );
            totalGrowthInvariant = totalNonExemptGrowthInvariant;
        } else if (_areAllTokensExempt()) {
            totalNonExemptGrowthInvariant = swapFeeGrowthInvariant;
            totalGrowthInvariant = StableMath._calculateInvariant(lastJoinExitAmp, balances);
        } else {
            totalNonExemptGrowthInvariant = StableMath._calculateInvariant(
                lastJoinExitAmp,
                _getAdjustedBalances(balances, false)
            );

            totalGrowthInvariant = StableMath._calculateInvariant(lastJoinExitAmp, balances);
        }
    }

    /// @dev for this specific pool only, this should be false
    function _areNoTokensExempt() internal pure returns (bool) {
        return false;
    }

    function _areAllTokensExempt() internal pure returns (bool) {
        return false;
    }

    function _getAdjustedBalances(
        uint256[] memory balances,
        bool ignoreExemptFlags
    ) internal view returns (uint256[] memory) {
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

    function _adjustedBalance(
        uint256 balance,
        uint256 registeredTokenIndex
    ) private view returns (uint256) {
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

    function _isTokenExemptFromYieldProtocolFee(
        uint256 registeredTokenIndex
    ) internal view returns (bool) {
        (IERC20[] memory tokens, , ) = IVault(BALANCER_VAULT).getPoolTokens(POOL_ID);
        return IBasePool(LP).isTokenExemptFromYieldProtocolFee(tokens[registeredTokenIndex]);
    }

    function _dropBptItemFromBalances(
        uint256[] memory registeredBalances
    ) internal view returns (uint256, uint256[] memory) {
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
