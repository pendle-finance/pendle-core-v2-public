// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IExecutorHelperStruct} from "../interfaces/IExecutorHelperStruct.sol";
import {IBebopV3} from "../interfaces/pools/IBebopV3.sol";
import {BytesHelper} from "../libraries/BytesHelper.sol";

library ScalingDataLib {
    using BytesHelper for bytes;

    function newUniSwap(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.UniSwap memory uniSwap = abi.decode(data, (IExecutorHelperStruct.UniSwap));
        uniSwap.collectAmount = (uniSwap.collectAmount * newAmount) / oldAmount;
        return abi.encode(uniSwap);
    }

    function newStableSwap(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.StableSwap memory stableSwap = abi.decode(data, (IExecutorHelperStruct.StableSwap));
        stableSwap.dx = (stableSwap.dx * newAmount) / oldAmount;
        return abi.encode(stableSwap);
    }

    function newCurveSwap(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.CurveSwap memory curveSwap = abi.decode(data, (IExecutorHelperStruct.CurveSwap));
        curveSwap.dx = (curveSwap.dx * newAmount) / oldAmount;
        return abi.encode(curveSwap);
    }

    function newUniV3ProMM(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.UniswapV3KSElastic memory uniSwapV3ProMM = abi.decode(
            data,
            (IExecutorHelperStruct.UniswapV3KSElastic)
        );
        uniSwapV3ProMM.swapAmount = (uniSwapV3ProMM.swapAmount * newAmount) / oldAmount;

        return abi.encode(uniSwapV3ProMM);
    }

    function newBalancerV2(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.BalancerV2 memory balancerV2 = abi.decode(data, (IExecutorHelperStruct.BalancerV2));
        balancerV2.amount = (balancerV2.amount * newAmount) / oldAmount;
        return abi.encode(balancerV2);
    }

    function newDODO(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.DODO memory dodo = abi.decode(data, (IExecutorHelperStruct.DODO));
        dodo.amount = (dodo.amount * newAmount) / oldAmount;
        return abi.encode(dodo);
    }

    function newGMX(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.GMX memory gmx = abi.decode(data, (IExecutorHelperStruct.GMX));
        gmx.amount = (gmx.amount * newAmount) / oldAmount;
        return abi.encode(gmx);
    }

    function newSynthetix(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.Synthetix memory synthetix = abi.decode(data, (IExecutorHelperStruct.Synthetix));
        synthetix.sourceAmount = (synthetix.sourceAmount * newAmount) / oldAmount;
        return abi.encode(synthetix);
    }

    function newCamelot(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.UniSwap memory camelot = abi.decode(data, (IExecutorHelperStruct.UniSwap));
        camelot.collectAmount = (camelot.collectAmount * newAmount) / oldAmount;
        return abi.encode(camelot);
    }

    function newPlatypus(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.Platypus memory platypus = abi.decode(data, (IExecutorHelperStruct.Platypus));
        platypus.collectAmount = (platypus.collectAmount * newAmount) / oldAmount;
        return abi.encode(platypus);
    }

    function newWrappedstETHSwap(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.WSTETH memory wstEthData = abi.decode(data, (IExecutorHelperStruct.WSTETH));
        wstEthData.amount = (wstEthData.amount * newAmount) / oldAmount;
        return abi.encode(wstEthData);
    }

    function newPSM(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.PSM memory psm = abi.decode(data, (IExecutorHelperStruct.PSM));
        psm.amountIn = (psm.amountIn * newAmount) / oldAmount;
        return abi.encode(psm);
    }

    function newStETHSwap(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        uint256 amount = abi.decode(data, (uint256));
        amount = (amount * newAmount) / oldAmount;
        return abi.encode(amount);
    }

    function newMaverick(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.Maverick memory maverick = abi.decode(data, (IExecutorHelperStruct.Maverick));
        maverick.swapAmount = (maverick.swapAmount * newAmount) / oldAmount;
        return abi.encode(maverick);
    }

    function newSyncSwap(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.SyncSwap memory syncSwap = abi.decode(data, (IExecutorHelperStruct.SyncSwap));
        syncSwap.collectAmount = (syncSwap.collectAmount * newAmount) / oldAmount;
        return abi.encode(syncSwap);
    }

    function newAlgebraV1(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.AlgebraV1 memory algebraV1Swap = abi.decode(data, (IExecutorHelperStruct.AlgebraV1));
        algebraV1Swap.swapAmount = (algebraV1Swap.swapAmount * newAmount) / oldAmount;
        return abi.encode(algebraV1Swap);
    }

    function newBalancerBatch(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.BalancerBatch memory balancerBatch = abi.decode(
            data,
            (IExecutorHelperStruct.BalancerBatch)
        );
        balancerBatch.amountIn = (balancerBatch.amountIn * newAmount) / oldAmount;
        return abi.encode(balancerBatch);
    }

    function newMantis(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.Mantis memory mantis = abi.decode(data, (IExecutorHelperStruct.Mantis));
        mantis.amount = (mantis.amount * newAmount) / oldAmount;
        return abi.encode(mantis);
    }

    function newIziSwap(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.IziSwap memory iZi = abi.decode(data, (IExecutorHelperStruct.IziSwap));
        iZi.swapAmount = (iZi.swapAmount * newAmount) / oldAmount;
        return abi.encode(iZi);
    }

    function newTraderJoeV2(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.TraderJoeV2 memory traderJoe = abi.decode(data, (IExecutorHelperStruct.TraderJoeV2));

        // traderJoe.collectAmount; // most significant 1 bit is to determine whether pool is v2.1, else v2.0
        traderJoe.collectAmount =
            (traderJoe.collectAmount & (1 << 255)) |
            ((uint256((traderJoe.collectAmount << 1) >> 1) * newAmount) / oldAmount);
        return abi.encode(traderJoe);
    }

    function newLevelFiV2(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.LevelFiV2 memory levelFiV2 = abi.decode(data, (IExecutorHelperStruct.LevelFiV2));
        levelFiV2.amountIn = (levelFiV2.amountIn * newAmount) / oldAmount;
        return abi.encode(levelFiV2);
    }

    function newGMXGLP(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.GMXGLP memory swapData = abi.decode(data, (IExecutorHelperStruct.GMXGLP));
        swapData.swapAmount = (swapData.swapAmount * newAmount) / oldAmount;
        return abi.encode(swapData);
    }

    function newVooi(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.Vooi memory vooi = abi.decode(data, (IExecutorHelperStruct.Vooi));
        vooi.fromAmount = (vooi.fromAmount * newAmount) / oldAmount;
        return abi.encode(vooi);
    }

    function newVelocoreV2(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.VelocoreV2 memory velocorev2 = abi.decode(data, (IExecutorHelperStruct.VelocoreV2));
        velocorev2.amount = (velocorev2.amount * newAmount) / oldAmount;
        return abi.encode(velocorev2);
    }

    function newMaticMigrate(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.MaticMigrate memory maticMigrate = abi.decode(data, (IExecutorHelperStruct.MaticMigrate));
        maticMigrate.amount = (maticMigrate.amount * newAmount) / oldAmount;
        return abi.encode(maticMigrate);
    }

    function newKokonut(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.Kokonut memory kokonut = abi.decode(data, (IExecutorHelperStruct.Kokonut));
        kokonut.dx = (kokonut.dx * newAmount) / oldAmount;
        return abi.encode(kokonut);
    }

    function newBalancerV1(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.BalancerV1 memory balancerV1 = abi.decode(data, (IExecutorHelperStruct.BalancerV1));
        balancerV1.amount = (balancerV1.amount * newAmount) / oldAmount;
        return abi.encode(balancerV1);
    }

    function newArbswapStable(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.ArbswapStable memory arbswapStable = abi.decode(
            data,
            (IExecutorHelperStruct.ArbswapStable)
        );
        arbswapStable.dx = (arbswapStable.dx * newAmount) / oldAmount;
        return abi.encode(arbswapStable);
    }

    function newBancorV2(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.BancorV2 memory bancorV2 = abi.decode(data, (IExecutorHelperStruct.BancorV2));
        bancorV2.amount = (bancorV2.amount * newAmount) / oldAmount;
        return abi.encode(bancorV2);
    }

    function newAmbient(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.Ambient memory ambient = abi.decode(data, (IExecutorHelperStruct.Ambient));
        ambient.qty = uint128((uint256(ambient.qty) * newAmount) / oldAmount);
        return abi.encode(ambient);
    }

    function newLighterV2(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.LighterV2 memory structData = abi.decode(data, (IExecutorHelperStruct.LighterV2));
        structData.amount = uint128((uint256(structData.amount) * newAmount) / oldAmount);
        return abi.encode(structData);
    }

    function newUniV1(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.UniV1 memory structData = abi.decode(data, (IExecutorHelperStruct.UniV1));
        structData.amount = uint128((uint256(structData.amount) * newAmount) / oldAmount);
        return abi.encode(structData);
    }

    function newEtherFiWeETH(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.EtherFiWeETH memory structData = abi.decode(data, (IExecutorHelperStruct.EtherFiWeETH));
        structData.amount = uint128((uint256(structData.amount) * newAmount) / oldAmount);
        return abi.encode(structData);
    }

    function newKelp(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.Kelp memory structData = abi.decode(data, (IExecutorHelperStruct.Kelp));
        structData.amount = uint128((uint256(structData.amount) * newAmount) / oldAmount);
        return abi.encode(structData);
    }

    function newEthenaSusde(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.EthenaSusde memory structData = abi.decode(data, (IExecutorHelperStruct.EthenaSusde));
        structData.amount = uint128((uint256(structData.amount) * newAmount) / oldAmount);
        return abi.encode(structData);
    }

    function newRocketPool(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.RocketPool memory structData = abi.decode(data, (IExecutorHelperStruct.RocketPool));

        uint128 _amount = uint128((uint256(uint128(structData.isDepositAndAmount)) * newAmount) / oldAmount);

        bool _isDeposit = (structData.isDepositAndAmount >> 255) == 1;

        // reset and create new variable for isDeposit and amount
        structData.isDepositAndAmount = 0;
        structData.isDepositAndAmount |= uint256(uint128(_amount));
        structData.isDepositAndAmount |= uint256(_isDeposit ? 1 : 0) << 255;

        return abi.encode(structData);
    }

    function newMakersDAI(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.MakersDAI memory structData = abi.decode(data, (IExecutorHelperStruct.MakersDAI));
        uint128 _amount = uint128((uint256(uint128(structData.isRedeemAndAmount)) * newAmount) / oldAmount);

        bool _isRedeem = (structData.isRedeemAndAmount >> 255) == 1;

        // reset and create new variable for isRedeem and amount
        structData.isRedeemAndAmount = 0;
        structData.isRedeemAndAmount |= uint256(uint128(_amount));
        structData.isRedeemAndAmount |= uint256(_isRedeem ? 1 : 0) << 255;

        return abi.encode(structData);
    }

    function newRenzo(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.Renzo memory structData = abi.decode(data, (IExecutorHelperStruct.Renzo));
        structData.amount = uint128((uint256(structData.amount) * newAmount) / oldAmount);
        return abi.encode(structData);
    }

    function newFrxETH(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.FrxETH memory structData = abi.decode(data, (IExecutorHelperStruct.FrxETH));
        structData.amount = uint128((uint256(structData.amount) * newAmount) / oldAmount);
        return abi.encode(structData);
    }

    function newSfrxETH(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.SfrxETH memory structData = abi.decode(data, (IExecutorHelperStruct.SfrxETH));
        structData.amount = uint128((uint256(structData.amount) * newAmount) / oldAmount);
        return abi.encode(structData);
    }

    function newSfrxETHConvertor(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.SfrxETHConvertor memory structData = abi.decode(
            data,
            (IExecutorHelperStruct.SfrxETHConvertor)
        );

        uint128 _amount = uint128((uint256(uint128(structData.isDepositAndAmount)) * newAmount) / oldAmount);

        bool _isDeposit = (structData.isDepositAndAmount >> 255) == 1;

        // reset and create new variable for isDeposit and amount
        structData.isDepositAndAmount = 0;
        structData.isDepositAndAmount |= uint256(uint128(_amount));
        structData.isDepositAndAmount |= uint256(_isDeposit ? 1 : 0) << 255;

        return abi.encode(structData);
    }

    function newOriginETH(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.OriginETH memory structData = abi.decode(data, (IExecutorHelperStruct.OriginETH));
        structData.amount = uint128((uint256(structData.amount) * newAmount) / oldAmount);
        return abi.encode(structData);
    }

    function newMantleUsd(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        uint256 isWrapAndAmount = abi.decode(data, (uint256));

        uint128 _amount = uint128((uint256(uint128(isWrapAndAmount)) * newAmount) / oldAmount);

        bool _isWrap = (isWrapAndAmount >> 255) == 1;

        // reset and create new variable for isWrap and amount
        isWrapAndAmount = 0;
        isWrapAndAmount |= uint256(uint128(_amount));
        isWrapAndAmount |= uint256(_isWrap ? 1 : 0) << 255;

        return abi.encode(isWrapAndAmount);
    }

    function newPufferFinance(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.PufferFinance memory structData = abi.decode(data, (IExecutorHelperStruct.PufferFinance));
        structData.permit.amount = uint128((uint256(structData.permit.amount) * newAmount) / oldAmount);
        return abi.encode(structData);
    }

    function newKyberRfq(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.KyberRFQ memory structData = abi.decode(data, (IExecutorHelperStruct.KyberRFQ));
        structData.amount = (structData.amount * newAmount) / oldAmount;
        return abi.encode(structData);
    }

    function newKyberLimitOrder(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.KyberLimitOrder memory structData = abi.decode(
            data,
            (IExecutorHelperStruct.KyberLimitOrder)
        );
        structData.params.takingAmount = (structData.params.takingAmount * newAmount) / oldAmount;
        structData.params.thresholdAmount = 1;
        return abi.encode(structData);
    }

    function newKyberDSLO(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.KyberDSLO memory structData = abi.decode(data, (IExecutorHelperStruct.KyberDSLO));
        structData.params.takingAmount = (structData.params.takingAmount * newAmount) / oldAmount;
        structData.params.thresholdAmount = 1;
        return abi.encode(structData);
    }

    function newNative(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        require(newAmount < oldAmount, "Native: not support scale up");

        IExecutorHelperStruct.Native memory structData = abi.decode(data, (IExecutorHelperStruct.Native));

        require(structData.multihopAndOffset >> 255 == 0, "Native: Multihop not supported");

        structData.amount = (structData.amount * newAmount) / oldAmount;

        uint256 amountInOffset = uint256(uint64(structData.multihopAndOffset >> 64));
        uint256 amountOutMinOffset = uint256(uint64(structData.multihopAndOffset));
        bytes memory newCallData = structData.data;

        newCallData = newCallData.update(structData.amount, amountInOffset);

        // update amount out min if needed
        if (amountOutMinOffset != 0) {
            newCallData = newCallData.update(1, amountOutMinOffset);
        }

        return abi.encode(structData);
    }

    function newHashflow(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        IExecutorHelperStruct.Hashflow memory structData = abi.decode(data, (IExecutorHelperStruct.Hashflow));
        structData.quote.effectiveBaseTokenAmount = (structData.quote.effectiveBaseTokenAmount * newAmount) / oldAmount;
        return abi.encode(structData);
    }

    function newBebop(bytes memory data, uint256 oldAmount, uint256 newAmount) internal pure returns (bytes memory) {
        require(newAmount < oldAmount, "Bebop: not support scale up");

        IExecutorHelperStruct.Bebop memory structData = abi.decode(data, (IExecutorHelperStruct.Bebop));

        structData.amount = (structData.amount * newAmount) / oldAmount;

        // update calldata with new swap amount
        (bytes4 selector, bytes memory callData) = structData.data.splitCalldata();

        (IBebopV3.Single memory s, IBebopV3.MakerSignature memory m, ) = abi.decode(
            callData,
            (IBebopV3.Single, IBebopV3.MakerSignature, uint256)
        );
        structData.data = bytes.concat(bytes4(selector), abi.encode(s, m, structData.amount));

        return abi.encode(structData);
    }

    function newSymbioticLRT(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.SymbioticLRT memory structData = abi.decode(data, (IExecutorHelperStruct.SymbioticLRT));
        structData.amount = (structData.amount * newAmount) / oldAmount;
        return abi.encode(structData);
    }

    function newMaverickV2(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperStruct.MaverickV2 memory structData = abi.decode(data, (IExecutorHelperStruct.MaverickV2));
        structData.collectAmount = (structData.collectAmount * newAmount) / oldAmount;
        return abi.encode(structData);
    }
}
