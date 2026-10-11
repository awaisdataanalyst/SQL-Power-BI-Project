# Phase 6 · Business Insights & Recommendations

**Project:** E-Commerce Delivery Performance & Customer Satisfaction (Olist) · **Tool:** MySQL 8

## Definitions & data notes

| Term | Used in | Definition |
|---|---|---|
| Late (≥1 day) | Phase 4 KPIs, AQ4, AQ5 | Delivered at least 1 calendar day after the estimated date. **6.77%** of 96,470 delivered orders (on-time 93.23%) |
| Late (strict) | I1, I3, S1, S2 | Delivered any time after the estimated timestamp. **7.99%** of 95,824 reviewed orders |

- The two definitions differ by **1,280 orders** that missed the estimate by hours on the same calendar day. Their 1-star rate is roughly 7–9% (derived from I1 vs I4), in line with on-time orders, so a same-day miss does not hurt customer satisfaction.
- I1 and I4 only include orders that have a review (95,824). S1 and S2 use all delivered orders; the KPIs and AQ4 use all 96,470, so small count differences are expected.
- S1 (state view) covers the 21 states with ≥300 orders (95,620 orders, 99% of volume). I3 covers sellers with ≥30 orders (627 sellers). S2 lists the 15 seller × category pairs with the most late orders (≥20 orders); an order is counted once per seller-category pair, so totals across pairs can slightly double-count multi-seller orders.

---

## Key insights

### 1. Late delivery is the strongest driver of bad reviews
| | Orders | Avg review | 1-star rate |
|---|---|---|---|
| On-time (strict) | 88,163 | 4.29 | 6.59% |
| Late (strict) | 7,661 | 2.57 | 46.21% |

Late orders score **1.72 points lower** and are **7.0x** more likely to get 1 star. Counting only orders ≥1 day late, the gap is wider: roughly 2.3 average review and ~54% 1-star (derived from the I4 buckets).

### 2. Review damage has a cliff at 4 days late
| Delay bucket | Orders | Avg review | 1-star rate |
|---|---|---|---|
| On-time / early (incl. same-day) | 89,443 | 4.29 | 6.6% |
| Late 1–3 days | 1,852 | 3.29 | 25.1% |
| Late 4–7 days | 1,748 | 2.10 | **58.6%** |
| Late 8+ days | 2,781 | 1.70 | 69.8% |

The 1-star rate jumps **+33pp** between the 1–3 and 4–7 day buckets, then plateaus around 70%. Preventing delays from crossing 3 days matters more than shaving the longest ones. Orders ≥1 day late are only **6.7%** of orders but produce **36.7%** of all 1-star reviews (AQ4), so delivery fixes address about a third of 1-stars; the other ~63% come from on-time or early orders.

### 3. Late rates vary almost 5x across states
| State | Orders | Avg delivery days | Avg promised days | Late orders | Late % (strict) |
|---|---|---|---|---|---|
| AL | 397 | 24.5 | 33.2 | 95 | **23.93** |
| MA | 717 | 21.5 | 31.1 | 141 | 19.67 |
| PI | 476 | 19.4 | 30.7 | 76 | 15.97 |
| CE | 1,279 | 21.2 | 32.0 | 196 | 15.32 |
| SE | 335 | 21.5 | 31.5 | 51 | 15.22 |
| BA | 3,256 | 19.3 | 30.1 | 457 | 14.04 |
| RJ | 12,350 | 15.2 | 27.0 | 1,664 | 13.47 |
| ES | 1,995 | 15.7 | 26.2 | 244 | 12.23 |
| RS | 5,344 | 15.2 | 29.2 | 382 | 7.15 |
| SP | 40,494 | 8.7 | 19.8 | 2,387 | 5.89 |
| MG | 11,354 | 11.9 | 25.2 | 637 | 5.61 |
| PR | 4,923 | 11.9 | 25.3 | 246 | 5.00 |

AL is **4.8x** PR's late rate and **4.1x** SP's. The six states at 14% or more (AL, MA, PI, CE, SE, BA) hold 6,460 orders (6.7% of volume) but 1,016 late orders (~13% of all late orders).

### 4. Lateness is not only a distance problem, and the far-state cushion is thin
- The six high-late states take **19–25 days** to deliver (2.2–2.8x SP's 8.7), yet their promised cushion (promised minus actual days) is only about **8.7–11.3 days**, no larger than SP's ~11.1. The big low-late states PR, MG and RS get about 13–14 days.
- **RJ** is not a remote state: it delivers in 15.2 days, the same as RS (7.15% late), yet is late 13.47% of the time. RJ alone has **1,664 late orders**, roughly 1 in 5 of all late orders from 12.8% of order volume. ES (15.7 days, 12.23% late) shows the same pattern.

### 5. Late orders are spread across many sellers, not a few bad ones
| Seller decile (by late rate) | Sellers | Orders | Late rate | Share of all late orders |
|---|---|---|---|---|
| 1 (worst) | 63 | 4,929 | 19.0% | 14.3% |
| 2 | 63 | 7,566 | 12.6% | 14.6% |
| 3 | 63 | 15,632 | 10.5% | **25.2%** |
| 4–10 | 438 | 53,520 | 1.0–9.0% | 45.9% |

The worst 10% of sellers cause only **14.3%** of late orders, and it takes the worst 30% to reach **54%**. Decile 3 is the biggest single pool: high-volume sellers (~248 orders each) with a moderate 10.5% late rate.

### 6. The biggest late-order pools are high-volume seller × category pairs, not the worst rates
| Seller | Category | Orders | Late orders | Late % |
|---|---|---|---|---|
| 4a3ca931 | bed_bath_table | 1,431 | 146 | 10.2 |
| 1f50f920 | garden_tools | 1,373 | 145 | 10.6 |
| ea8482cd | telephony | 1,109 | 116 | 10.5 |
| 4869f7a5 | watches_gifts | 974 | 115 | 11.8 |
| 8b321bb6 | electronics | 838 | 91 | 10.9 |
| 06a2c3af | health_beauty | 389 | 90 | **23.1** |
| 6560211a | watches_gifts | 1,438 | 88 | 6.1 |
| da8622b1 | bed_bath_table | 1,071 | 86 | 8.0 |
| 7c67e144 | office_furniture | 882 | 84 | 9.5 |
| 1025f0e2 | furniture_decor | 785 | 81 | 10.3 |
| 7a67c85e | cool_stuff | 1,051 | 64 | 6.1 |
| 81602554 | bed_bath_table | 375 | 63 | **16.8** |
| 7d13fca1 | watches_gifts | 489 | 58 | 11.9 |
| fa1c13f2 | watches_gifts | 572 | 58 | 10.1 |
| cc419e06 | health_beauty | 1,020 | 57 | 5.6 |

These 15 pairs hold 13,797 orders (14.3% of volume) and **1,342 late orders (~17% of all late orders)** at a 9.7% late rate, only modestly above the 7.99% average, so volume drives the count more than rate. Three pairs of similar volume (1,020–1,438 orders) already run at **5.6–6.1%**. Two smaller pairs are clear outliers (06a2c3af at 23.1%, 81602554 at 16.8%). watches_gifts and bed_bath_table make up 7 of the 15 pairs (614 late orders, 46% of the list); this analysis cannot separate a seller effect from a category effect.

### 7. Three months account for about half of all late orders
Nov-2017 (87.60% on-time), Feb-2018 (85.87%) and Mar-2018 (81.04%) are ~21.6% of orders but ~48% of late orders (≈3,160 of ≈6,530). In Mar-2018 the 1-star rate hit 17.52% vs 7.1–9.0% in healthy months. Feb–Mar 2018 volume was flat versus January while on-time fell ~13pp, so capacity alone does not explain it.

---

## Recommendations

### R1 · Seller performance thresholds and warnings
- **Tier 1 (watchlist):** sellers with ≥30 orders and late rate above ~12% (about the worst 20%, ~126 sellers; decile averages 19.0% and 12.6%).
- **Tier 2 (action plan, then review):** late rate above ~19% or 1-star rate above 25%. Two pairs from Insight 6 already qualify as Tier 2 candidates: 06a2c3af (health_beauty, 23.1% late on 389 orders) and 81602554 (bed_bath_table, 16.8% on 375 orders).
- Thresholds are starting points; confirm exact decile cut-offs before applying.

**Estimated impact:** bringing deciles 1–2 to the platform level (~8%) removes about **890 late orders** (13.7% of late orders), cutting the seller-order late rate from 7.99% to **~6.9%**. If those late orders had on-time-like reviews, that is up to ~350 fewer 1-star orders.

### R2 · Volume-weighted priority list for high-volume sellers and seller × category pairs
Rank sellers and pairs by **late order count**, not only late rate. Start with the 15 pairs in Insight 6 and the high-volume sellers in decile 3 (63 sellers, 25.2% of late orders). The top SP seller (4869f7a5) alone has 115 late orders on 974 watches_gifts orders.

**Estimated impact:**
- (a) Cutting decile 3's late rate from 10.5% to ~7% removes about **550 late orders** (8.4% of seller-level late orders).
- (b) Cutting the 15 pairs from 9.7% to 6% (a rate three similar-volume pairs already achieve) removes about **510 late orders** (~6.5% of all late orders).
- (b) overlaps with (a) and partly with R1, so do not add them. R1 + R2(a) together: ~1,440 late orders, seller-order late rate **7.99% → ~6.2%**.

### R3 · Targeted delivery-window changes for six high-late states, plus an RJ operations audit
- Add **+3 days** to estimated windows in **AL, MA, PI, CE, SE, BA** (late 14–24%, cushion of only ~9–11 days despite 19–25 day deliveries), which brings their cushion to roughly the 13–14 days that PR, MG and RS get. Test +3/+5/+7 days as an A/B test; do not apply a blanket change to every remote state.
- Run a carrier/seller-mix audit for **RJ** (13.47% late at the same delivery time as RS), since a window change would hide a problem that is not distance-related.

**Estimated impact:** the six states have 6,460 orders and 1,016 late orders (15.7%). Using the national delay mix (29% of late orders are 1–3 days late, 56% are ≤7 days late), **+3 days** reclassifies about **295 orders** as on-time (up to ~55 fewer 1-star orders) and **+7 days** about **570 orders** (up to ~200 fewer 1-star, upper bound). If RJ reached MG's 5.61% late rate, it would remove about **970 late orders**. A longer promise only fixes expectations, not actual speed, and may cost conversion.

### R4 · Peak-month capacity planning and a 3-day early-warning rule
- Add carrier/fulfilment capacity for Nov and Feb–Mar, and alert when monthly on-time drops below 92% or the 3-month average below 90%.
- Flag orders likely to miss the estimate by 3+ days for proactive messaging or compensation, since the 1-star rate jumps from 25% to 59% beyond that point.

**Estimated impact:** bringing the three bad months to a 95% on-time baseline removes about **2,100 late orders** (late rate 6.77% → ~4.6%) and ~1,500 1-star orders. Keeping 4–7 day delays within the 1–3 day bucket's 1-star rate saves about **600 1-star orders**.

---

## Caveats
- Impacts are what-if estimates, not forecasts, and overlap between recommendations, so they should not be added together. They also use different late definitions and order bases (see Definitions).
- The 1-star savings assume that late orders would have reviewed like on-time orders; real recovery is likely smaller. The window-change estimates assume the national delay mix applies to the six states.
- Findings are observational and correlational. This analysis has no cost data and covers 2016–2018 Olist orders only.
- Small states (<300 orders) and low-volume sellers (<30 orders) are excluded; seller IDs are shortened to 8 characters.
