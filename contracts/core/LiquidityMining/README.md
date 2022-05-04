# vePendle

### Locking PENDLE for vePendle (on ETH)
* Each user can only lock for a maximum of $MAXLOCKTIME$ = 2 years
* vePendle balance for users is represented by:
$balance_u(t) = bias_u - slope_u * t$

* As such, we just need to store $bias_u$ and $slope_u$ for each user. (Considerations: store $bias_u$ and $t_{expiry}$ for the user instead, because $t_{expiry}$ is always an exact number)
* The amount of PENDLE locked by user $u$ is $locked_u$
* For total supply, it's simply $totalBalance = totalBias - totalSlope * t$
* Possible actions by an user:
    * User $u$ create a new lock by locking $d_{PENDLE}$ of PENDLE tokens, expiring at $t_{expiry}$:
        $bias_u = d_{PENDLE} * t_{expiry} / MAXLOCKTIME$
        $slope_u = bias_u / t_{expiry}$
    * User $u$ locks an additional of $d_{PENDLE}$ PENDLE tokens, into his existing lock expiring at $t_{expiry}$
        $bias_{u_{new}} = bias_u + d_{PENDLE} * bias_u / locked_u$
        $slope_{u_{new}} = bias_{u_{new}} / t_{expiry}$
    * User $u$ extends his expiry from $t_{expiry}$ to $t_{expiry_{new}}$
        $bias_{u_{new}} = t_{expiry_{new}} * bias_u / t_{expiry}$
        $slope_{u_{new}} = bias_{u_{new}} / t_{expiry_{new}}$
        
* Similar to Curve:
    * We store the checkpoints for when a user's $slope$ or $bias$ changes
    * We restrict the possible expiries to exact weeks from UNIX timestamp 0
    * We store the global bias and slope changes due to expiry of user's vote-locks per week, and process it when the week comes

### Cross-chain messaging module
* There is a contract `GovernancePortal` on governance chain - Ethereum, with a function `sendMessage(chain Y, sender, message)` to send messages to other chains.
* On each non-governance chain, we have a `CrosschainPortal` contract . Let's call `CrosschainPortal_X` the `CrosschainPortal` contract on chain X
* Each `CrosschainPortal` contract has a function `afterReceivingMessage(sender, message)` to receive the message from governance.
* When `sendMessage(chain Y, sender, message)` is called on governance chain, `afterReceivingMessage(sender, message)`  will be called on chain Y, thanks to the cross-chain messaging module
* The current mechanics for the module is using Celer
* The cross-chain messaging module can be plugged in/plugged out by the governance address (which will initially be controlled by a team multisig)

### Voting for incentives on market and chains
* On Ethereum, there is a `VotingController` contract to control the voting on incentives for the different markets on the different chains.
* Adding a new chain:
    * The governance address will be able to add a new chain, together with the MarketFactory address of the chain.
* There is a list of `(chain, market)` that are elligible for the voting
    * For a new `(chain, market)` to be included: there has to be a message `("newMarket", marketAddress, expiry)` being sent from the MarketFactory in a chain X to Ethereum.
    * markets that are expired will be automatically excluded from the voting
* vePendle holders can allocate their vePendle to multiple markets on multiple chains
* Similar to Curve, we store the bias and slope of the total vePendle voted for every market
    * Similary, we adjust the slope/bias changes due to expired vePendle at the weekly mark
* The `VotingController` will receive PENDLE directly from the PENDLE token contract (weekly emissions), which can be triggered by anyone
    * **Consideration**: just manually get PENDLE from PENDLE token contract & fund gauge controllers
        * GaugeControllers: admin can withdraw PENDLE from it
* For each chain, there will be a `assignedBridger` address that is responsible for briding the PENDLE incentives to that chain
* At any point in time, any one can call the `VotingController` to distribute the PENDLE sitting inside among the `assignedBridger` addresses. These `assignedBridger` addresses are supposed to bridge the PENDLE to the `GaugeController` in the respective chain
    * The `assignedBridger` can be a multisig, or a contract with customised logic to bridge tokens to the correct chain
* In each chain, there is a `GaugeController` contract that is responsible for keeping PENDLE incentives and distributing PENDLE to incentivise different markets.
* There is a global PENDLE per second rate for all the incentives across all the chains. This is set by governance.
* At any point in time, anyone can call a function `broadcastVotes()` in `VotingController` to broadcast to every chain:
    1. The current allocation between the chains, and hence the PENDLE per second rate for each chain.
    2. The weights among the markets in each chain
    When this happens, the `GaugeController` in each chain will update the PENDLE per second as well as the weights among the different markets
* The governance address could blacklist a market
* The governance address could dictate the votes for another x% of the vePendle supply (x is a config, <= 20)

### USDC global rewards for vePendle holders
* As people lock PENDLE to get vePendle, we track this index:
    *  $i(t) = \int_{0}^t totalVePendleBalance \times dt$
* At certain timestamps, there could be an influx of USDC into the vePENDLE pool (from YT fees). This amount of USDC will be distributed equally to the "vePendleSeconds" since the last time USDC is distributed to the pool. Basically, we track an index $incomeindex$ of "how many USDC a user would have, per vePendleSeconds, if he stakes from the very beginning".
    * $incomeIndex(t) += newUsdc / ( i(t) - i(t_{lastUsdcDistribution}) )$
* For each user, we track how many vePendleSeconds he has since the last time he claimed USDC rewards, and distribute the pending rewards to them

### USDC rewards for vePendle voters for certain markets
* At certain timestamps, there could be an influx of USDC into the vePENDLE pool (from swap fees) that should be distributed to the vePendle voters of the respective pool.
* Similar to the USDC global rewards accounting, we track the total "vePendleSeconds" for every market, and distribute the USDC rewards proportionally to the "vePendleSeconds" since the last distribution.
* For each user, we track the "vePendleSeconds" for each of them since the last reward claim, and multiply with the incomeIndex for each "vePendleSeconds"

### Any third party rewards for vePendle voters for certain markets
* Third party protocols/people should be able to give rewards to vePendle voters of a certain pool (basically bribing them) in some ways. We could use some similar mechanisms to the previous section

### GaugeController
* This contract on each chain will receive all the SCY reward tokens from all the markets, and will distribute the rewards to the stakers for the respective markets, following the same formulas as distributing PENDLE
    * Basically, the reward tokens are basically another type of incentives, that could be boosted by vePendle balance
* When a market is created by the MarketFactory, the MarketFactory will call the GaugeController to create a respective gauge as well. Basically, there can only be one gauge for a market. Consideration: any reasons for multiple gauges per market ?
* The mechanics for boosting PENDLE incentives is the same as Curve

### Broadcasting vePendle balance & different address for boosting rewards for each chain
* At anytime, an address A could send a cross message to update the vePendle balance on a specific chain
* At the very first time an address sends the cross chain message to update vePendle balance on a chain X, it can specify an alternative address to be the "counterpart address" on chain X.
    * The "counterpart address" on chain X needs to send a crosschain message to accepts the pairing.
    * Once a pairing is done, the "counterpart address" will be boosted by the vePendle balance of address A in Ethereum