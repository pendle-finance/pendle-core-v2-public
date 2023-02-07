// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./interfaces/IExecutorHelperEthereum1.sol";

library ScaleDataHelperEthereum1 {
    function newUniSwap(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperEthereum1.UniSwap memory uniSwap = abi.decode(
            data,
            (IExecutorHelperEthereum1.UniSwap)
        );
        uniSwap.collectAmount = (uniSwap.collectAmount * newAmount) / oldAmount;
        return abi.encode(uniSwap);
    }

    function newStableSwap(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperEthereum1.StableSwap memory stableSwap = abi.decode(
            data,
            (IExecutorHelperEthereum1.StableSwap)
        );
        stableSwap.dx = (stableSwap.dx * newAmount) / oldAmount;
        return abi.encode(stableSwap);
    }

    function newCurveSwap(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperEthereum1.CurveSwap memory curveSwap = abi.decode(
            data,
            (IExecutorHelperEthereum1.CurveSwap)
        );
        curveSwap.dx = (curveSwap.dx * newAmount) / oldAmount;
        return abi.encode(curveSwap);
    }

    function newKyberDMM(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperEthereum1.UniSwap memory kyberDMMSwap = abi.decode(
            data,
            (IExecutorHelperEthereum1.UniSwap)
        );
        kyberDMMSwap.collectAmount = (kyberDMMSwap.collectAmount * newAmount) / oldAmount;
        return abi.encode(kyberDMMSwap);
    }

    function newUniV3ProMM(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperEthereum1.UniSwapV3ProMM memory uniSwapV3ProMM = abi.decode(
            data,
            (IExecutorHelperEthereum1.UniSwapV3ProMM)
        );
        uniSwapV3ProMM.swapAmount = (uniSwapV3ProMM.swapAmount * newAmount) / oldAmount;

        return abi.encode(uniSwapV3ProMM);
    }

    function newBalancerV2(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperEthereum1.BalancerV2 memory balancerV2 = abi.decode(
            data,
            (IExecutorHelperEthereum1.BalancerV2)
        );
        balancerV2.amount = (balancerV2.amount * newAmount) / oldAmount;
        return abi.encode(balancerV2);
    }

    function newDODO(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperEthereum1.DODO memory dodo = abi.decode(
            data,
            (IExecutorHelperEthereum1.DODO)
        );
        dodo.amount = (dodo.amount * newAmount) / oldAmount;
        return abi.encode(dodo);
    }

    function newSynthetix(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperEthereum1.Synthetix memory synthetix = abi.decode(
            data,
            (IExecutorHelperEthereum1.Synthetix)
        );
        synthetix.sourceAmount = (synthetix.sourceAmount * newAmount) / oldAmount;
        return abi.encode(synthetix);
    }

    function newWrappedstETHSwap(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperEthereum1.WSTETH memory wstEthData = abi.decode(
            data,
            (IExecutorHelperEthereum1.WSTETH)
        );
        wstEthData.amount = (wstEthData.amount * newAmount) / oldAmount;
        return abi.encode(wstEthData);
    }

    function newPSM(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperEthereum1.PSM memory psm = abi.decode(data, (IExecutorHelperEthereum1.PSM));
        psm.amountIn = (psm.amountIn * newAmount) / oldAmount;
        return abi.encode(psm);
    }

    function newFrax(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperEthereum1.UniSwap memory frax = abi.decode(
            data,
            (IExecutorHelperEthereum1.UniSwap)
        );
        frax.collectAmount = (frax.collectAmount * newAmount) / oldAmount;
        return abi.encode(frax);
    }
}
