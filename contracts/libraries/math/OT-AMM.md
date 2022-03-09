# OT AMM
* [Back](YieldMarket.md)
## Overview
* This is a an AMM for trading OT against its corresponding LYT
* The AMM design aims to achieve a few things
  * It's capital efficient, which allows for trading relatively large size with low slippage
  * It preserves a consistent interest rate over time (interest rate continuity), if no trades happen
    * It means that people should only trade with the AMM if they think the interest will change, and not because of other factors like underlying asset price or time
  * It will dynamically change its formula over time to approach a constant sum formula (1 OT = 1 accounting asset) after the expiry
  * It allows for explicitly setting the tradeoff between capital efficiency and the reasonable trading range

## Virtual accounting asset balance
* Although the actual tokens sitting in the AMM's account are OT and LYTs, from the AMM's perspective, we will pretend that we have OT and accounting assets instead.
* As such, this is really an AMM for trading OT against accounting assets
* In terms of how the AMM's logic works, at any point in time, we will pretend that we have `totalCash` accounting assets and `totalOt` OTs, where `totalCash = totalLYT * LYT.exchangeRate`
* Although `totalCash` will increase by itself, we will treat it as if it's just somebody sending accounting assets into the AMM.
* Note that at expiry, 1 unit of `OT` will be exchangable to an amount of `LYT` that has the same value as 1 unit of `cashUnderlying`

## Parameters set at the beginning of the market

### `scalarRoot`
* **Definition:** a scalar factor to adjust the initial capital efficiency (by adjusting the slope of the exchange rate graph)
### `scalarRoot`
* **Definition:** an initial anchor rate to anchor the initial AMM formula to be more capital efficient around that interest rate
### `feeRateRoot`
* **Definition:** the initial fees factor, denominated in interest rate

## The definitions

### `periodSize`
* **Definition:** the period which all rates will be normalized to. For Pendle's AMM, this will be fixed to 1 year.

### `proportion`
* **Definition:** the proportion of total values of `OT` over the total value of the market.

    $$ proportion = \frac{totalOt}{totalOt+totalCash}$$

### `scalar(t)`
* **Definition:** the scalar to use for the equation at any time `t`
    $$ scalar(t) = \frac{scalarRoot \times periodSize}{timeToExpiry(t)}$$

### `lastImpliedRate`
* **Definition:** the implied interest rate of the latest trade on the AMM. This will be updated after every successful trade on the AMM.

### `impliedRate` -> `extRate` conversion
* Because the interest model of all yield bearing assets are also continuos compounding, our conversion formula will have to depend on the continuos compounding formula.
* Consider the continuos compounding interest rate formula:
    $$FutureValue(t) = PresentValue \times e^{interestRate \times t}$$

    whereas `t` is the time denominated in years
* Hence we have our conversion formula:
    $$extRate = e^{\frac{impliedRate \times timeToExpiry}{periodSize}}$$

### `extRate` -> `impliedRate` conversion

$$impliedRate = ln(extRate) \times periodSize \div timeToExpiry$$

### `impliedExtRate`
* **Definition:** the exchange rate inferred from `lastImpliedRate` assuming no additional yield were generated. In other words, if no additional yield were generated, when the user trade with this exchange rate, they will enjoy the same interest rate as the previous trade.
    $$impliedExtRate = e^{\frac{lastImpliedRate \times timeToExpiry}{periodSize}}$$

### `anchor(t)`
* **Definition:** To maintain the interest rate continuity, we will have to adjust `anchor` before every trade. This can be done using the `impliedExtRate` above.
    $$ anchor(t) = impliedExtRate - ln(\frac{proportion}{1-proportion}) \div scalar(t)$$


### `extRate(t)`
* **Definition:** the spot exchange rate of `cashUnderlying` to `OT` at any time `t`, without any fees.
    $$ extRate(t) = \frac{1}{scalar(t)} \times ln(\frac{proportion}{1-proportion}) + anchor(t)$$

---
Note: Params only related to the trade

### `tradeProportion`
$$ tradeProportion = \frac{(totalOt \pm amountOtToMarket)}{totalOt+totalCash}$$

### `tradeExtRateNoFee(t)`
* **Definition:** the exchange rate used for this trade, without fee. This rate will satisfy the following equation:
    $$ amountCashToAccount = \frac{amountOtToMarket}{tradeExtRateNoFee}(t)$$
* It will be calculated as follows:
    $$ tradeExtRateNoFee(t) = \frac{1}{scalar(t)} \times ln(\frac{tradeProportion}{1-tradeProportion}) + anchor(t)$$

### `feeRate(t)`
* **Definition:** a fee to levy on every trade. The fee is denominated in interest rate and will be converted to an exchange rate to apply to trades. The conversion is the same as `impliedRate` -> `extRate`.
    $$feeRate(t) = exp\left(\frac{feeRateRoot \times timeToExpiry}{periodSize}\right)$$

### `tradeExtRate(t)`
* Since the `feeRate(t)` is denominated in interest rate but needed to be applied on the exchangeRate, we can think of the `tradeExtRate(t)`as:
    $$tradeExtRate(t) = exp((tradeImpliedRateNoFee(t) \pm feeRateRoot) \times \frac{timeToExpiry}{periodSize})$$
    $$=> tradeExtRate(t) = exp(tradeImpliedRateNoFee(t) \times \frac{timeToExpiry}{periodSize} \pm feeRateRoot \times \frac{timeToExpiry}{periodSize})$$
    $$=> tradeExtRate(t) = exp(tradeImpliedRateNoFee(t) \times \frac{timeToExpiry}{periodSize}) [\times or \div] exp(feeRateRoot \times \frac{timeToExpiry}{periodSize})$$
    $$=> tradeExtRate(t) = tradeExtRateNoFee(t) [\times or \div] feeRate(t)$$

* If the trade is from `LYT` to `OT`, this fee will be subtracted from the implied rate (i.e divided from the exchange rate) so that users will receive less `OT`. The reverse apply for `OT` to `LYT` trade.

### Swapping logic
* TBD



### Adding/removing liquidity
* TBD

### TWAP for OT prices
* Use the same approach as UniswapV3 to store the culmulative sums of `price * time` in an array
* Link to Uniswap docs: https://uniswap.org/blog/uniswap-v3#advanced-oracles

