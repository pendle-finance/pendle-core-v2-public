---
"@pendle/core-v2": minor
---

feat(PTLooping)!: Request life cycle with an executor and a checker, and a Morpho flash loan

- The executor sends `execute(execution, checkerSig)`, which runs `execution.calls` as delegatecalls into the looper. The checker signs `Execution(bytes[] calls,uint256 deadline)` (EIP-712), with `calls` hashed as a standard EIP-712 `bytes[]`: the `keccak256` of the concatenated `keccak256` of each call. There is no nonce: a signed execution can run again until its deadline. The executor functions run only inside `execute`.
- In an `eth_call` with a zero `tx.origin`, `execute` runs the calls with no signature or deadline (a simulation), and returns the results.
- `checker` and `setChecker` replace `proposer` and `setProposer`. The entry points take `(message, request)` with no signatures. `BoxPermit`, `proposerNonce` and `userRequest` are removed.
- `approveRequest(owner, requestHash, ownerSig)` (the owner, or the executor with the owner's signature) replaces `preApproveRequest`. `terminateRequest(owner, requestHash)` (the owner, or the executor) replaces `terminateSession`. The statuses are `DEFAULT`, `APPROVED` and `TERMINATED`. A request runs many iterations until its expiry. `IncreasePositionMessage.swapInitToken` selects the input token.
- The owner limits are request fields: `initMinToPtSwapRate`, `minDebtToPtSwapRate` and `minPtToDebtSwapRate`. Each message has `minSwapRate`. The swap must meet the higher of the two rates.
- `RequestHeader` signs `offchainMetadataHash` in place of `offchainMetadata`.
- Morpho flash loan for an increase or a decrease in one transaction (`flashAmount` in the messages).
- `settleBox(owner, boxId, repayDebt, lendPt, tokensToOwner)`: the executor repays, lends, and sends the tokens of a box to its owner. It needs no request.
- Removed: `claimMMRewards` and the money market `claimRewards`; the `hashRaw` and `hashTyped` getters (calculate the EIP-712 hashes off-chain).
- Money markets: the looper emits the money market events. `lend`, `borrow`, `repay` and `withdraw` return only the actual amount. A `withdraw` of an amount that is not zero from an empty position reverts.
- Gas: constant EIP-712 name and version; in-place EIP-712 hashing; no box call for a zero-amount withdraw; no oracle read when a decrease leaves no debt.
- `PostPtLoopStateChecker.check(ctx, data)` takes the `MarketCtx` of the looper in place of the box; the checker has no constructor argument.
