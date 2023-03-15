// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IExecutorHelper1} from './IExecutorHelper1.sol';

library ScaleDataHelper1 {
  function newUniSwap(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal pure returns (bytes memory) {
    IExecutorHelper1.UniSwap memory uniSwap = abi.decode(data, (IExecutorHelper1.UniSwap));
    uniSwap.collectAmount = (uniSwap.collectAmount * newAmount) / oldAmount;
    return abi.encode(uniSwap);
  }

  function newStableSwap(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal pure returns (bytes memory) {
    IExecutorHelper1.StableSwap memory stableSwap = abi.decode(data, (IExecutorHelper1.StableSwap));
    stableSwap.dx = (stableSwap.dx * newAmount) / oldAmount;
    return abi.encode(stableSwap);
  }

  function newCurveSwap(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal pure returns (bytes memory) {
    IExecutorHelper1.CurveSwap memory curveSwap = abi.decode(data, (IExecutorHelper1.CurveSwap));
    curveSwap.dx = (curveSwap.dx * newAmount) / oldAmount;
    return abi.encode(curveSwap);
  }

  function newKyberDMM(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal pure returns (bytes memory) {
    IExecutorHelper1.UniSwap memory kyberDMMSwap = abi.decode(data, (IExecutorHelper1.UniSwap));
    kyberDMMSwap.collectAmount = (kyberDMMSwap.collectAmount * newAmount) / oldAmount;
    return abi.encode(kyberDMMSwap);
  }

  function newUniV3ProMM(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal pure returns (bytes memory) {
    IExecutorHelper1.UniSwapV3ProMM memory uniSwapV3ProMM = abi.decode(data, (IExecutorHelper1.UniSwapV3ProMM));
    uniSwapV3ProMM.swapAmount = (uniSwapV3ProMM.swapAmount * newAmount) / oldAmount;

    return abi.encode(uniSwapV3ProMM);
  }

  function newBalancerV2(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal pure returns (bytes memory) {
    IExecutorHelper1.BalancerV2 memory balancerV2 = abi.decode(data, (IExecutorHelper1.BalancerV2));
    balancerV2.amount = (balancerV2.amount * newAmount) / oldAmount;
    return abi.encode(balancerV2);
  }

  function newDODO(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal pure returns (bytes memory) {
    IExecutorHelper1.DODO memory dodo = abi.decode(data, (IExecutorHelper1.DODO));
    dodo.amount = (dodo.amount * newAmount) / oldAmount;
    return abi.encode(dodo);
  }

  function newVelodrome(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal pure returns (bytes memory) {
    IExecutorHelper1.UniSwap memory velodrome = abi.decode(data, (IExecutorHelper1.UniSwap));
    velodrome.collectAmount = (velodrome.collectAmount * newAmount) / oldAmount;
    return abi.encode(velodrome);
  }

  function newGMX(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal pure returns (bytes memory) {
    IExecutorHelper1.GMX memory gmx = abi.decode(data, (IExecutorHelper1.GMX));
    gmx.amount = (gmx.amount * newAmount) / oldAmount;
    return abi.encode(gmx);
  }

  function newSynthetix(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal pure returns (bytes memory) {
    IExecutorHelper1.Synthetix memory synthetix = abi.decode(data, (IExecutorHelper1.Synthetix));
    synthetix.sourceAmount = (synthetix.sourceAmount * newAmount) / oldAmount;
    return abi.encode(synthetix);
  }

  function newCamelot(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal pure returns (bytes memory) {
    IExecutorHelper1.UniSwap memory camelot = abi.decode(data, (IExecutorHelper1.UniSwap));
    camelot.collectAmount = (camelot.collectAmount * newAmount) / oldAmount;
    return abi.encode(camelot);
  }
}
