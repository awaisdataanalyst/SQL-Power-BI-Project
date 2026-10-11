# Cleaning Log — Olist E-Commerce Delivery Performance

**Database:** MySQL 8 · `olist_ecommerce`
**Principle:** Raw tables are never modified. All cleaning happens in `*_clean` tables, so every step is reproducible via `02_cleaning.sql`.

---

## 0. Baseline (raw row counts)

| Table | Rows |
|---|---|
| orders | 99,441 |
| order_reviews | 99,224 |
| products | 32,951 |
| category_translation | 71 |

---

## 1. NULL audit — orders

| Check | Count | Decision |
|---|---|---|
| NULL `order_approved_at` | 160 | Kept in `orders_clean`, flagged (`flag_null_approved`) |
| NULL `order_delivered_carrier_date` | 1,783 | Kept, not used in delivery metrics |
| NULL `order_delivered_customer_date` | 2,965 (Phase 1: 2,965) | Flagged; excluded from `orders_delivered` |
| Status `delivered` but NULL delivery date | 8 | Excluded from `orders_delivered` (cannot compute delivery time) |
| Status `delivered` but NULL approval | 14 | Kept (approval not needed for delivery time) |

**Why not delete?** NULL dates are mostly legitimate (order not yet shipped/delivered). Deleting would distort order-volume and cancellation analysis.

## 2. Canceled / unavailable orders

| Status | Rows | Decision |
|---|---|---|
| canceled | 625 | Kept in `orders_clean` (`is_cancelled_or_unavailable = 1`); excluded from delivery-time analysis |
| unavailable | 609 | Same as above |
| other non-delivered (shipped, processing, invoiced, created, approved) | 1,729 | Excluded from `orders_delivered` — delivery not complete |

**Effect:** `orders_clean` 99,441 rows → `orders_delivered` 96,470 rows (2,971 rows excluded in total: 2,963 non-delivered status + 8 delivered with NULL delivery date)

## 3. Date logic validation

| Rule | Violations | Decision |
|---|---|---|
| approved < purchase | 0 | Flagged only |
| carrier date < purchase | 166 | Flagged only |
| **delivered < purchase** (impossible) | 0 | No violations found, no rows removed |
| delivered < carrier date | 23 | Flagged only (likely timestamp-logging issue) |
| estimated < purchase | 0 | Flagged only |
| negative `delivery_days` after cleaning | 0 (must be 0) | — |

**Note on negative delay:** `delay_days = delivered − estimated`. A negative value means the order arrived **early** — this is valid business data, not an error, so it is kept.
Early: 88,644 · On estimated day: 1,292 · Late: 6,534

## 4. Duplicate reviews

| Metric | Value |
|---|---|
| Review rows (raw) | 99,224 |
| Distinct orders with a review | 98,673 |
| Extra rows removed | 551 |
| Rows after (`reviews_clean`) | 98,673 |

**Rule:** keep the **latest** review per order (`review_answer_timestamp DESC`, tie-break `review_creation_date`, then `review_pk`), because the latest score reflects the customer's final opinion.
Score range check (1–5): Passed — only scores 1 to 5 exist, no invalid or NULL scores (1: 11,424 · 2: 3,151 · 3: 8,179 · 4: 19,142 · 5: 57,328 = 99,224 rows).

## 5. Category standardization

| Check | Value |
|---|---|
| Products (raw) | 32,951 |
| Products with NULL category | 610 → labelled `unknown` |
| Categories missing from translation table | 2 (list below) |
| Rows after (`products_clean`) | 32,951 (must equal raw) |
| Products labelled `unknown` after mapping | 610 (only the NULL-category products) |

Manual mappings added:
- `pc_gamer` (3 products) → `pc_gamer`
- `portateis_cozinha_e_preparadores_de_alimentos` (10 products) → `portable_kitchen_and_food_preparers`

## 6. Final row-count summary

| Table | Before | After | Change | Reason |
|---|---|---|---|---|
| orders → orders_clean | 99,441 | 99,441 | 0 | Flags only, no deletion |
| orders_clean → orders_delivered | 99,441 | 96,470 | -2,971 | Non-delivered / NULL delivery / impossible dates |
| order_reviews → reviews_clean | 99,224 | 98,673 | -551 | Duplicate reviews per order |
| products → products_clean | 32,951 | 32,951 | 0 | Category standardized, no deletion |

## 7. Known limitations
- Reviews exist for only some orders → always `LEFT JOIN` reviews in Phase 3+.
- `unknown` category products stay in the data; exclude them only for category-level charts.
