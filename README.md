# Pendle V2
This repository contains the core smart contracts for the Pendle V2 Protocol.

## Whitepapers
Specifications for how Pendle V2 Protocol works can be read in our 4 whitepapers at [this link](https://github.com/pendle-finance/pendle-v2-resources/tree/main/whitepapers)

## Audits
Pendle V2 contracts have been auditted by 6 auditors. The reports could be found in the `audits` folder

## Documentations
We have included documentations on how things work in the contract codes. There will be more documentations to come, which will be updated here when they are available.

## Using solidity interfaces
The contract interfaces are available for import into solidity smart contracts
via the npm artifact `@pendle/core-v2`, e.g.:

```solidity
import '@pendle/core-v2/contracts/interfaces/IPMarket.sol';

contract MyContract {
  IPMarket market;

  function doSomethingWithMarket() {
    // market.mint(...);
  }
}

```