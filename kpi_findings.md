# Phase 4 – KPI Analysis Findings
**Project:** E-Commerce Delivery Performance & Customer Satisfaction (Olist) · **Database:** MySQL 8 · **Script:** `04_kpis.sql`

**Scope:** delivered orders only (96,470). Monthly trends cover Jan 2017 – Aug 2018. Currency is Brazilian Real (R$).

## Headline KPIs (BQ2)
| KPI | Value |
|---|---|
| Delivered orders | 96,470 |
| GMV (price + freight) | R$ 15.42M |
| AOV | R$ 159.83 |
| On-time delivery % | 93.23% |
| Average delivery time | 12.5 days |
| Average review score | 4.16 |
| % 1-star reviews | 9.76% |
| Repeat customer rate | 3.00% (2,801 of 93,350 customers) |

## BQ1 – Growth trend
- Monthly GMV grew from **R$ 127K (Jan 2017)** to over **R$ 1.1M** from Jan 2018 onward. Peaks: Nov 2017 (R$ 1.15M, 7,288 orders) and Apr 2018 (R$ 1.13M).
- AOV slowly drifted down from about R$ 170 to about R$ 155, so growth came from more orders, not bigger baskets.

## BQ3 – How late are late orders?
| Status | Orders | % | Avg delay (days) | Avg delivery (days) |
|---|---|---|---|---|
| On time | 89,936 | 93.23 | -13.5 | 10.9 |
| Late | 6,534 | 6.77 | +10.6 | 33.9 |

- On-time orders arrive on average **13.5 days before** the estimated date, which means Olist's estimates are very conservative. The 93% on-time rate is therefore a generous KPI; average delivery days and late-order share are better to watch.
- Late orders take about 3x longer than on-time orders (33.9 vs 10.9 days).

## BQ4 – Late delivery vs customer satisfaction (key finding)
| Delay bucket | Orders | Avg review | % 1-star |
|---|---|---|---|
| Early 7+ days | 76,140 | 4.31 | 6.49 |
| On time (0–6 days early) | 13,796 | 4.17 | 7.34 |
| Late 1–3 days | 1,870 | 3.29 | 25.11 |
| Late 4–7 days | 1,802 | 2.10 | 58.58 |
| Late 8–14 days | 1,478 | 1.67 | 70.61 |
| Late 15+ days | 1,384 | 1.72 | 68.99 |

- Even **1–3 days late** raises the 1-star share to about 3.5x the on-time level; from 4 days late, more than half of reviews are 1-star.
- The damage levels off after about 8 days late (about 70% 1-star).
- Late orders are only 6.8% of deliveries, but by a rough estimate they generate about **35–40% of all 1-star reviews**.
- This shows a strong association, not proof of causation.

## Monthly pattern (v_monthly_kpis)
| Month | On-time % | Avg delivery days | Avg review | % 1-star |
|---|---|---|---|---|
| 2017-11 | 87.60 | 15.1 | 3.99 | 13.09 |
| 2018-02 | 85.87 | 16.9 | 3.88 | 15.64 |
| 2018-03 | **81.04** | 16.2 | **3.81** | **17.52** |
| 2018-06 | 98.84 | 9.2 | 4.31 | 7.13 |
| 2018-08 | 93.81 | 7.7 | 4.31 | 7.05 |

- Months with low on-time % (Nov 2017, Feb–Mar 2018) line up with the highest 1-star rates, repeating the BQ4 pattern at monthly level.
- Delivery days fell sharply in mid-2018. Caution: the latest months may look better because very slow orders from those months may not have been delivered by the data cut-off.

## BQ5 – Weakest states (500+ orders, lowest on-time %)
| State | Orders | On-time % | Avg delivery days | Avg review | % 1-star |
|---|---|---|---|---|---|
| MA | 717 | 82.57 | 21.5 | 3.83 | 15.73 |
| CE | 1,279 | 86.24 | 21.2 | 3.94 | 13.51 |
| BA | 3,256 | 87.84 | 19.3 | 3.93 | 13.19 |
| RJ | 12,350 | 87.89 | 15.2 | 3.97 | 14.75 |
| PA | 946 | 88.79 | 23.7 | 3.91 | 14.36 |

- Most weak states are in the North/Northeast (MA, CE, BA, PA, PB, PE) and have the longest delivery times (up to 23.7 days in PA).
- **RJ stands out:** it is close to the main seller hub, yet only 87.9% on time. With 12,350 orders it has the largest number of late orders among weak states (about 1,500), so it offers the biggest absolute improvement.

## BQ6 – Categories with most 1-star reviews (300+ orders)
| Category | Orders | On-time % | Avg review | % 1-star |
|---|---|---|---|---|
| office_furniture | 1,254 | 92.03 | 3.52 | 20.44 |
| audio | 348 | 88.40 | 3.84 | 16.20 |
| home_confort | 392 | 90.68 | 3.85 | 15.93 |
| unknown (no category) | 1,392 | 92.52 | 3.94 | 15.74 |
| furniture_decor | 6,307 | 92.97 | 3.95 | 13.84 |
| bed_bath_table | 9,272 | 92.97 | 3.92 | 13.81 |

- Furniture and home categories dominate the list.
- `office_furniture` has the worst 1-star rate (20.4%) while its on-time % is near average, so its problem is probably not delivery (possible causes: product quality, assembly, or description mismatch; needs review text to confirm).
- 1,392 orders have no product category (data quality gap).
- Category figures are calculated per item row, so multi-item orders are weighted by items.

## BQ7 – Where does the delay come from? (average days per stage)
| Status | Approval | Seller handling | Carrier |
|---|---|---|---|
| On time | 0.41 | 2.58 | 7.96 |
| Late | 0.50 | 5.53 | 27.87 |

- The gap between late and on-time orders is about 23 days, of which **about 87% (19.9 days) is carrier transit time**, about 13% (3 days) is seller handling, and almost nothing is approval.
- Late deliveries are mainly a logistics/carrier problem; seller dispatch speed is a smaller second factor.

## BQ8 – Repeat purchases
| First order | Customers | Repeat customers | Repeat rate |
|---|---|---|---|
| On time | 86,993 | 2,639 | 3.03% |
| Late | 6,357 | 162 | 2.55% |

- Only **3.0%** of customers ordered more than once, so Olist is mostly a one-time-purchase marketplace.
- A late first order is linked to a slightly lower repeat rate (2.55% vs 3.03%), but the gap is small and based on only 162 repeaters, so it is not conclusive.

## Recommendations
1. **Fix carrier transit first:** it explains most of the lateness; focus on North/Northeast routes and on RJ because of its volume.
2. **Protect peak months:** Black Friday (Nov 2017) and Feb–Mar 2018 show service dropping when volume is high.
3. **Add proactive delay communication:** a delay of 4+ days almost guarantees a bad review, so alerts or compensation for late orders could limit damage.
4. **Review furniture categories** (especially office_furniture) for product-quality or description issues.
5. **Clean missing categories** (1,392 orders) and consider tighter, more realistic delivery estimates.
6. **Improve retention:** a 3% repeat rate suggests room for loyalty or re-engagement campaigns.

## Next steps
- Power BI dashboard using the views `v_monthly_kpis`, `v_delivered_base` and `v_repeat_rate`.
- Optional: text analysis of review comments, seller-level performance.
