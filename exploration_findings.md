# Phase 3 – Exploratory Analysis Findings
**Project:** E-Commerce Delivery Performance & Customer Satisfaction (Olist) · **Database:** MySQL 8 · **Script:** `03_exploration.sql`

## 1. Dataset size (Q1)
| Table | Rows |
|---|---|
| customers | 99,441 |
| orders | 99,441 |
| order_items | 112,650 |
| order_payments | 103,886 |
| order_reviews | 99,224 |
| products | 32,951 |
| sellers | 3,095 |
| category_translation | 71 |

- `order_items` > `orders` because an order can contain several items.
- `order_payments` > `orders` because an order can be paid with more than one method (e.g. voucher + credit card).

## 2. Time coverage (Q2, Q3)
- Orders span **2016-09-04 to 2018-10-17** (773 days).
- 2016 is very sparse (Sep: 4, Oct: 324, Nov: no orders, Dec: 1) and Sep–Oct 2018 are almost empty (16 and 4 orders).
- Reliable analysis window: **Jan 2017 – Aug 2018** (20 full months).
- Volume grows from 800 orders (Jan 2017) to about 7,000 per month in 2018, with a peak of **7,544 in Nov 2017** (likely Black Friday).

## 3. Order status (Q4)
| Status | Orders | % |
|---|---|---|
| delivered | 96,478 | 97.02 |
| shipped | 1,107 | 1.11 |
| canceled | 625 | 0.63 |
| unavailable | 609 | 0.61 |
| invoiced | 314 | 0.32 |
| processing | 301 | 0.30 |
| created | 5 | 0.01 |
| approved | 2 | 0.00 |

- 97% of orders are delivered, so delivery KPIs will be based on a large, reliable sample.
- `orders_delivered` (cleaned) has 96,470 rows, i.e. 8 "delivered" orders without a delivery date were excluded in Phase 2.

## 4. Product categories (Q6, Q7)
- **Top by items sold:** bed_bath_table (11,115), health_beauty (9,670), sports_leisure (8,641).
- **Top by revenue:** health_beauty (R$ 1.26M), watches_gifts (R$ 1.21M), bed_bath_table (R$ 1.04M).
- `watches_gifts` ranks 7th by volume but 2nd by revenue (average item price about R$ 201 vs about R$ 93 for bed_bath_table), so it is a high-value, low-volume category.
- Revenue here is item price only (freight excluded).

## 5. Geography (Q8)
- Customers are concentrated in the Southeast: **SP 41.98%, RJ 12.92%, MG 11.70%** (top 3 = 66.6% of orders).
- Next: RS, PR, SC, BA, DF, ES, GO (each between 2% and 5.5%).
- Expect delivery time to vary by state (distance from sellers), which is worth testing in Phase 4.

## 6. Payment mix (Q10)
| Type | Payments | Value (R$) | % of value |
|---|---|---|---|
| credit_card | 76,795 | 12.54M | 78.34 |
| boleto | 19,784 | 2.87M | 17.92 |
| voucher | 5,775 | 0.38M | 2.37 |
| debit_card | 1,529 | 0.22M | 1.36 |
| not_defined | 3 | 0 | 0.00 |

- Credit card dominates; boleto (bank slip) is the second most used method.
- 3 `not_defined` payments have zero value and can be ignored.

## 7. Review scores (Q12, cleaned reviews: 98,673)
| Score | Reviews | % |
|---|---|---|
| 1 | 11,363 | 11.52 |
| 2 | 3,131 | 3.17 |
| 3 | 8,133 | 8.24 |
| 4 | 19,038 | 19.29 |
| 5 | 57,008 | 57.77 |

- Average score is about **4.09**. 77% of reviews are 4–5 stars.
- The distribution is J-shaped: 1-star (11.5%) is clearly larger than 2-star (3.2%), which suggests a group of customers with a specific bad experience (to be tested against late deliveries).

## 8. Delivery time (Q15, delivered orders)
- Average **12.5 days** from purchase to delivery.
- Min 0 days and max 210 days, so both ends look like outliers.

## Points to handle in Phase 4 (KPIs)
1. Restrict monthly trends to Jan 2017 – Aug 2018.
2. Use `orders_delivered` for delivery KPIs.
3. Check delivery-time percentiles (median, P90, P95) instead of relying on the average only, and review the 0-day and very long deliveries.
4. Compare actual vs estimated delivery date (on-time %).
5. Link review score with late vs on-time delivery.
6. Compare delivery time and satisfaction by state and by category.
