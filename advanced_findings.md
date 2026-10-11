# Phase 5 – Advanced SQL Analysis Findings
**Project:** E-Commerce Delivery Performance & Customer Satisfaction (Olist) · **Database:** MySQL 8 · **Scripts:** `05_advanced.sql`, `05b_fix_performance.sql`

**Techniques used:** `RANK() OVER`, `RANK() OVER (PARTITION BY)`, `LAG()`, running totals with `SUM() OVER`, moving average, CTEs inside views, cohort-style first-vs-repeat analysis, `EXPLAIN`, indexing and table materialisation.

**Grain:** one row per (seller, order) in `v_seller_orders` (97,811 rows from 96,470 delivered orders, because some orders contain items from several sellers). Seller rankings include only the **425 sellers with 50+ delivered orders** (out of 2,970 active sellers).

## AQ1 – Seller scorecard: best sellers (quality rank = on-time rank + review rank)
| Seller (short id) | State | Orders | GMV (R$) | On-time % | Avg review | % 1-star | GMV rank |
|---|---|---|---|---|---|---|---|
| d566c37f… | SP | 65 | 5,146 | 100.00 | 4.69 | 3.13 | 348 |
| e882b2a2… | RJ | 57 | 51,058 | 100.00 | 4.58 | 1.75 | 36 |
| 12b9676b… | RS | 133 | 26,376 | 99.25 | 4.55 | 2.27 | 86 |
| 080199a1… | SP | 79 | 14,504 | 98.73 | 4.62 | 1.28 | 152 |
| 744dac40… | PR | 78 | 22,323 | 98.72 | 4.58 | 2.56 | 102 |

- The best-quality sellers are mostly **small to mid-size** (GMV rank 36 to 402 out of 425), so good service does not depend on volume.
- Caution: with only 50–130 orders each, a perfect on-time rate can partly be luck.

## AQ2 – Weakest sellers
| Seller (short id) | State | Orders | On-time % | Avg delivery (days) | Avg handling (days) | Avg review | % 1-star |
|---|---|---|---|---|---|---|---|
| 54965bbe… | PR | 73 | 69.86 | 26.1 | 14.87 | 3.14 | 36.23 |
| a49928bc… | SP | 96 | 78.13 | 16.8 | 6.85 | 3.03 | 34.38 |
| 1ca7077d… | SP | 108 | 83.33 | 15.5 | 5.29 | 2.39 | 52.34 |
| 712e6ed8… | SC | 77 | 79.22 | 24.6 | 7.38 | 3.39 | 22.37 |
| 88460e8e… | PR | 246 | 82.93 | 17.8 | 7.43 | 3.43 | 26.53 |

- Weak sellers take **5 to 15 days to hand orders to the carrier**, versus about 2.6 days for an average on-time order (Phase 4). So seller dispatch speed is a real lever for this group, even though carrier transit explains most lateness overall.
- Seller `1ca7077d…` is 83% on time but has a 52% 1-star rate and a 2.39 average score. Its problem is probably the product or listing, not delivery.
- PR appears three times in the bottom 10.

## AQ3 – Top seller by GMV in each state (RANK with PARTITION BY)
| State | Orders | GMV (R$) | On-time % | Avg review |
|---|---|---|---|---|
| SP | 1,124 | 226,988 | 89.50 | 4.15 |
| BA | 348 | 217,940 | 96.55 | 4.19 |
| RJ | 503 | 122,811 | 94.23 | 4.27 |
| MG | 702 | 99,309 | 95.01 | 4.28 |
| MA | 389 | 36,098 | 80.98 | 4.01 |

- Thirteen states have a clear leader. The SP leader (`4869f7a5…`) is on time only 89.5% of the time (below the 93.2% average) and is **#3 in the late-order Pareto** (118 late orders).
- The MA leader (`06a2c3af…`) is on time only 81% and is **#11 in the Pareto** (74 late orders).
- A BA seller reaches R$ 218K GMV, close to the SP leader.

## AQ4 – Delay bucket vs review (with LAG)
| Bucket | Orders | % of orders | Avg review | Change vs previous bucket | % 5-star | % 1-star | % of all 1-star |
|---|---|---|---|---|---|---|---|
| Early 7+ days | 76,140 | 78.93 | 4.31 | – | 63.36 | 6.49 | 52.55 |
| On time (0–6 early) | 13,796 | 14.30 | 4.17 | -0.15 | 56.22 | 7.34 | 10.76 |
| Late 1–3 days | 1,870 | 1.94 | 3.29 | -0.87 | 33.15 | 25.11 | 4.97 |
| Late 4–7 days | 1,802 | 1.87 | 2.10 | **-1.19** | 14.07 | 58.58 | 10.95 |
| Late 8–14 days | 1,478 | 1.53 | 1.67 | -0.43 | 6.85 | 70.61 | 10.92 |
| Late 15+ days | 1,384 | 1.43 | 1.72 | +0.05 | 7.19 | 68.99 | 9.85 |

- The biggest single drop in satisfaction is between "late 1–3 days" and "late 4–7 days" (-1.19 points). After about 8 days late the score stops falling.
- Being only 1–3 days late cuts the 5-star share from 56% to 33%.
- Late orders (6.8% of deliveries) produce about **37% of all 1-star reviews**. This confirms the Phase 4 estimate.
- **Important balance:** about **63% of 1-star reviews come from on-time or early orders**, so lateness is only part of the satisfaction problem. Product quality and listing accuracy need attention too.

## AQ5 – Month-over-month change (LAG)
| Month | GMV MoM % | Orders MoM % | On-time change (pp) | 1-star change (pp) |
|---|---|---|---|---|
| 2017-11 | +53.54 | +62.75 | -8.22 | +4.52 |
| 2017-12 | -26.89 | -24.36 | +4.94 | -2.29 |
| 2018-02 | -10.36 | -7.27 | -8.43 | +5.30 |
| 2018-03 | +15.98 | +6.83 | -4.83 | +1.88 |
| 2018-04 | +1.10 | -2.93 | +14.46 | -8.78 |
| 2018-08 | -4.07 | +3.17 | -2.81 | -0.22 |

- Growth was steepest in early 2017 (Feb: +112.8% GMV) and spiked again in Nov 2017 (+53.5%, Black Friday).
- Both service drops (Nov 2017 and Feb–Mar 2018) happen right after volume surges, which points to **capacity strain**. Each drop is followed by a recovery (Dec 2017 and Apr 2018).
- The 3-month average on-time rate bottoms out at 87.1% in Mar 2018.
- From Apr 2018, orders flatten at about 6,000–7,000 per month and GMV slips from R$ 1.13M (Apr) to R$ 0.99M (Aug). In Aug 2018 orders grew +3.2% while GMV fell -4.1%, so AOV is falling (R$ 166.88 to R$ 155.17).

## AQ6 – Pareto of late orders by seller
- Top 10 sellers account for **15.7%** of late orders; top 20 for **24.6%** (only 1.6% of the sellers that had a late order).
- **398 sellers (31.2% of the 1,274 sellers with late orders) cause 80% of late orders.** That is 13.4% of all 2,970 active sellers.
- 1,274 of 2,970 sellers (42.9%) had at least one late order.
- The distribution is flatter than a classic 80/20 rule: late orders are spread over many sellers, which matches the Phase 4 finding that carrier transit, not individual sellers, is the main driver.
- Note: this Pareto counts late orders, so large sellers rank high partly because of volume. The scorecard (late *rate*) is the fairer view for performance management.

## AQ7 – First vs repeat customers
**7a. Order type comparison**
| Type | Orders | AOV (R$) | On-time % | Avg delivery (days) | Avg review | % 1-star |
|---|---|---|---|---|---|---|
| First order | 93,350 | 160.24 | 93.19 | 12.5 | 4.15 | 9.80 |
| Repeat order | 3,120 | 147.30 | 94.33 | 12.1 | 4.24 | 8.64 |

**7b. Repeat rate by review score on the first order**
| First-order score | Customers | Repeat customers | Repeat rate % |
|---|---|---|---|
| 1 | 9,084 | 261 | 2.87 |
| 2 | 2,832 | 78 | 2.75 |
| 3 | 7,669 | 227 | 2.96 |
| 4 | 18,356 | 500 | 2.72 |
| 5 | 54,792 | 1,712 | 3.12 |

**7c.** For 3,075 repeat orders the previous order scored 4.22 on average and the repeat order 4.24.

- Repeat orders have a slightly smaller basket (R$ 147 vs R$ 160) and a slightly better experience.
- The repeat rate barely changes with the first-order score (2.7% to 3.1%). Even unhappy first-time customers (1-star) come back at 2.87%, almost the same as 5-star customers (3.12%). So in this dataset satisfaction has only a weak link with repeat purchase, and low repeat is a structural feature of the marketplace.

## Performance tuning
**Before (measured in MySQL Workbench, no materialisation):**
| Query | Duration |
|---|---|
| Monthly KPI view (20 rows) | 8.9 s |
| First vs repeat comparison (7a) | 8.6 s |
| Repeat order score with LAG (7c) | 9.2 s |
| Row count of `v_seller_scorecard` / `v_seller_orders` | 18.0 s / 18.5 s |
| Pareto top 20 (6a) | 18.9 s |
| Best seller per state (AQ3) | 20.4 s |
| Repeat rate by first score (7b) | 24.3 s |
| Pareto summary (6b) | **47.4 s** (first attempt hit the 30 s client timeout, Error 2013) |

**1. Diagnosis with `EXPLAIN`** (late orders per seller, `v_seller_orders`)
- The plan has 11 rows and **three derived tables materialised in temporary tables** (`Using temporary`), one of them also with `Using filesort` (the `ROW_NUMBER()` window in `v_delivered_base`). The derived tables are read with full scans (`type = ALL`); the optimizer even estimates about 1.28M rows for the outer one, although the real data is about 97K rows, because derived tables have no statistics.
- Every base table is already joined through an index (`eq_ref` / `ref` on `PRIMARY` for `order_id`, `customer_id`, `seller_id`). `SHOW INDEX` confirmed that `order_items`, `orders_delivered`, `customers`, `reviews_clean`, `products` and `sellers` already have primary keys, plus seller, product, category and customer-unique-id indexes.
- **Conclusion:** the slowness is not caused by missing join indexes. It comes from the view stack being recomputed on every call (window function plus temporary tables), and the 8–9 s floor on even a 20-row query shows that fixed cost.

**2. Index experiment (negative result)**
- I added indexes on the join columns and ran `ANALYZE TABLE` (0.66 s).
- `EXPLAIN` after the change shows the **same plan**: the optimizer still chooses `PRIMARY`, and the new indexes only appear in `possible_keys`, never in `key`. The only difference is refreshed row estimates (for example `reviews_clean` 97,902 to 97,461).
- These indexes duplicated existing ones, so they were dropped again (cleanup step in `05b_fix_performance.sql`). Lesson: check `SHOW INDEX` and `EXPLAIN` before adding indexes, because an index the optimizer does not choose only costs write time and storage.

**3. Materialisation (the actual fix)**
- The heavy base view is stored once as a real table (`t_delivered_base`, indexed on `order_id`, `customer_unique_id` and `order_month`) and the seller-level table `t_seller_orders` is built from it; the views are then pointed at these tables.
- Test join of the delivered-orders base with `order_items` (110,189 rows, same result both times):
| Source | Duration |
|---|---|
| `v_delivered_base` (view, recomputed) | 12.1 s and 12.3 s (two runs) |
| `t_delivered_base` (materialised table) | **2.5 s** (about 4.8x faster) |
- Row count of the seller-order data: `SELECT COUNT(*)` on `v_seller_orders` took 18.5 s, on `t_seller_orders` it takes **0.25 s** (about 74x faster), and both return the same 97,811 rows.
- Validation: `t_delivered_base` has 96,470 rows (equal to the delivered orders from Phase 4) and `t_seller_orders` has 97,811 rows (equal to the old view), so materialising did not change the data.
- One-time build cost: creating the indexes took about 1 s each (`idx_tdb_month` 0.95 s, `idx_tso_order` 1.27 s).

**After (re-run the same queries once `05b_fix_performance.sql` has been applied):**
| Query | Before | After |
|---|---|---|
| Pareto summary (6b) | 47.4 s | **0.39 s** (about 120x faster) |
| Best seller per state (AQ3) | 20.4 s | **0.64 s** (about 32x faster) |
| Repeat rate by first score (7b) | 24.3 s | **1.64 s** (about 15x faster) |

The result sets are unchanged (AQ3 still returns 13 rows and 7b 5 rows). Overall, materialising two heavy views turned queries that took 20–47 s into queries that finish in about 0.4–1.6 s, with no change to the SQL logic.

## Recommendations
1. **Seller management:** use the scorecard to coach or watch the bottom sellers, especially those with 5–15 day handling times. Track late *rate*, not just late count.
2. **Look beyond delivery for satisfaction:** 63% of 1-star reviews come from on-time orders, so review product quality and listing accuracy (for example the SP seller with 83% on-time but 52% 1-star).
3. **Plan for peaks:** service dropped after the Nov 2017 and Feb 2018 volume surges; add carrier capacity before expected peaks.
4. **Fix the leaders in weak regions:** the top sellers in SP and MA are also among the biggest sources of late orders, so improving them has outsized effect.
5. **Watch AOV and growth:** orders and GMV flattened in 2018 and basket size is drifting down.
6. **Retention:** repeat purchases are rare (3%) and not driven by satisfaction alone, so loyalty offers rather than service fixes are the lever to test.
