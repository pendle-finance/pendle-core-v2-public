// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../../core/libraries/math/PMath.sol";
import "../../../core/libraries/math/LogExpMath.sol";

library MarketDeployLib {
    using PMath for uint256;
    using PMath for int256;
    using LogExpMath for uint256;
    using LogExpMath for int256;

    uint256 internal constant YEAR = 365 days;
    uint256 internal constant LN_9 = 2197224577336219648;

    struct CalcParamsArgs {
        uint256 yearsToExpiry;
        uint256 rateMinScaled;
        uint256 rateMaxScaled;
        uint256 rateDiff;
    }

    function calcParams(
        uint256 rateMin,
        uint256 rateMax,
        uint256 expiry
    ) internal view returns (uint256 scalarRoot, uint256 initialRateAnchor) {
        CalcParamsArgs memory args;

        args.yearsToExpiry = (expiry - block.timestamp).divDown(YEAR);
        args.rateMinScaled = (rateMin + PMath.ONE).pow(args.yearsToExpiry);
        args.rateMaxScaled = (rateMax + PMath.ONE).pow(args.yearsToExpiry);

        // [initRateAnchor]
        initialRateAnchor = (args.rateMinScaled + args.rateMaxScaled) / 2;

        args.rateDiff = args.rateMaxScaled - initialRateAnchor;

        // [scalarRoot]
        scalarRoot = (LN_9 * args.yearsToExpiry) / args.rateDiff;
    }

    struct CalcInitialProportionArgs {
        uint256 timeToExpiry;
        uint256 lnImpliedRate;
        int256 desiredExchangeRate;
        uint256 lnProportion;
    }

    function calcInitialProportion(
        uint256 expiry,
        uint256 scalarRoot,
        uint256 rateAnchor,
        uint256 desiredImpliedRate
    ) internal view returns (uint256 initialProportion) {
        CalcInitialProportionArgs memory args;

        args.timeToExpiry = expiry - block.timestamp;
        args.lnImpliedRate = LogExpMath.ln(PMath.IONE + desiredImpliedRate.Int()).Uint();
        args.desiredExchangeRate = ((args.lnImpliedRate * args.timeToExpiry) / YEAR).Int().exp();

        uint256 rateScalar = (scalarRoot * YEAR) / args.timeToExpiry;
        int256 logitP = (args.desiredExchangeRate - rateAnchor.Int()).mulDown(rateScalar.Int()).exp();
        initialProportion = (logitP.divDown(PMath.IONE + logitP)).Uint();
    }

    function calcFee(uint256 fee) internal pure returns (uint80 lnFeeRateRoot) {
        return (PMath.ONE + fee).Int().ln().Uint().Uint80();
    }
}
