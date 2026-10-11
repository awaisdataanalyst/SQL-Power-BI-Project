-- =====================================================================
-- Phase 5 : Advanced SQL Analysis  |  Olist E-Commerce (MySQL 8)
-- Part A  : Seller-level views (run once, after 04_kpis.sql views exist)
-- Part B  : Advanced queries AQ1-AQ7 (RANK, LAG, Pareto, cohorts)
-- Part C  : Performance tuning (EXPLAIN, indexes, materialisation)
--
-- Grain notes
--   * v_seller_orders has one row per (seller, order). An order with items
--     from 2 sellers appears twice, once per seller.
--   * The review score belongs to the order, so in multi-seller orders
--     both sellers share the same review (small effect, documented).
--   * Seller rankings only include sellers with 50+ delivered orders.
-- =====================================================================
USE olist_ecommerce;

-- =====================================================================
-- PART A : VIEWS
-- =====================================================================

-- A1. One row per seller and order, with delivery and review outcome
CREATE OR REPLACE VIEW v_seller_orders AS
SELECT oi.seller_id,
       s.seller_state,
       oi.order_id,
       SUM(oi.price)                    AS seller_gmv,
       MAX(b.order_month)               AS order_month,
       MAX(b.is_on_time)                AS is_on_time,
       MAX(b.delay_days)                AS delay_days,
       MAX(b.delivery_days)             AS delivery_days,
       MAX(b.review_score)              AS review_score,
       MAX(TIMESTAMPDIFF(HOUR, od.order_approved_at,
                               od.order_delivered_carrier_date)) / 24 AS handling_days
FROM order_items oi
JOIN v_delivered_base    b  ON b.order_id  = oi.order_id
JOIN orders_delivered    od ON od.order_id = oi.order_id
JOIN sellers             s  ON s.seller_id = oi.seller_id
GROUP BY oi.seller_id, s.seller_state, oi.order_id;

-- A2. Seller scorecard with RANK() on volume, punctuality and reviews
CREATE OR REPLACE VIEW v_seller_scorecard AS
WITH seller_stats AS (
    SELECT seller_id,
           seller_state,
           COUNT(*)                                AS orders,
           ROUND(SUM(seller_gmv), 2)               AS gmv,
           ROUND(100 * AVG(is_on_time), 2)         AS on_time_pct,
           ROUND(AVG(delivery_days), 1)            AS avg_delivery_days,
           ROUND(AVG(handling_days), 2)            AS avg_handling_days,
           ROUND(AVG(review_score), 2)             AS avg_review_score,
           ROUND(100 * AVG(review_score = 1), 2)   AS pct_1star
    FROM v_seller_orders
    GROUP BY seller_id, seller_state
    HAVING COUNT(*) >= 50
),
ranked AS (
    SELECT ss.*,
           RANK() OVER (ORDER BY gmv DESC)              AS gmv_rank,
           RANK() OVER (ORDER BY on_time_pct DESC)      AS on_time_rank,
           RANK() OVER (ORDER BY avg_review_score DESC) AS review_rank
    FROM seller_stats ss
)
SELECT r.*,
       on_time_rank + review_rank                              AS quality_points,
       RANK() OVER (ORDER BY on_time_rank + review_rank)       AS quality_rank
FROM ranked r;

-- A3. Pareto view: late orders per seller with cumulative share
CREATE OR REPLACE VIEW v_seller_late_pareto AS
WITH late AS (
    SELECT seller_id, COUNT(*) AS late_orders
    FROM v_seller_orders
    WHERE is_on_time = 0
    GROUP BY seller_id
),
ranked AS (
    SELECT seller_id,
           late_orders,
           SUM(late_orders) OVER (ORDER BY late_orders DESC, seller_id) AS cum_late,
           ROW_NUMBER()     OVER (ORDER BY late_orders DESC, seller_id) AS rn,
           SUM(late_orders) OVER ()                                     AS total_late,
           COUNT(*)         OVER ()                                     AS n_sellers
    FROM late
)
SELECT rn                                         AS seller_rank,
       seller_id,
       late_orders,
       total_late,
       n_sellers,
       ROUND(100 * late_orders / total_late, 2)   AS pct_of_late,
       ROUND(100 * cum_late / total_late, 2)      AS cum_pct_late,
       ROUND(100 * rn / n_sellers, 2)             AS cum_pct_sellers
FROM ranked;

-- Quick check that the views work
SELECT COUNT(*) AS seller_order_rows FROM v_seller_orders;
SELECT COUNT(*) AS ranked_sellers    FROM v_seller_scorecard;

-- =====================================================================
-- PART B : ADVANCED QUERIES
-- =====================================================================

-- ---------------------------------------------------------------------
-- AQ1. Seller scorecard: top 10 sellers by overall quality rank
--      (quality = on-time rank + review rank, ties broken by GMV)
-- ---------------------------------------------------------------------
SELECT seller_id, seller_state, orders, gmv,
       on_time_pct, avg_review_score, pct_1star,
       gmv_rank, on_time_rank, review_rank, quality_rank
FROM v_seller_scorecard
ORDER BY quality_rank, gmv DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- AQ2. Seller scorecard: 10 weakest sellers (worst quality rank)
-- ---------------------------------------------------------------------
SELECT seller_id, seller_state, orders, gmv,
       on_time_pct, avg_delivery_days, avg_handling_days,
       avg_review_score, pct_1star, quality_rank
FROM v_seller_scorecard
ORDER BY quality_rank DESC, gmv DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- AQ3. Best seller in each state by GMV (RANK with PARTITION BY)
-- ---------------------------------------------------------------------
SELECT seller_state, seller_id, orders, gmv, on_time_pct,
       avg_review_score, state_gmv_rank
FROM (
    SELECT seller_state, seller_id, orders, gmv, on_time_pct, avg_review_score,
           RANK() OVER (PARTITION BY seller_state ORDER BY gmv DESC) AS state_gmv_rank
    FROM v_seller_scorecard
) x
WHERE state_gmv_rank = 1
ORDER BY gmv DESC;

-- ---------------------------------------------------------------------
-- AQ4. Delay bucket vs review: star distribution, share of all 1-star
--      reviews, and score drop versus the previous bucket (LAG)
-- ---------------------------------------------------------------------
SELECT bucket,
       COUNT(*)                                               AS orders,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)       AS pct_of_orders,
       ROUND(AVG(review_score), 2)                            AS avg_review_score,
       ROUND(AVG(review_score) - LAG(AVG(review_score)) OVER (ORDER BY bucket), 2)
                                                              AS score_change_vs_prev_bucket,
       ROUND(100 * AVG(review_score = 5), 2)                  AS pct_5star,
       ROUND(100 * AVG(review_score = 1), 2)                  AS pct_1star,
       SUM(review_score = 1)                                  AS one_star_reviews,
       ROUND(100 * SUM(review_score = 1)
             / SUM(SUM(review_score = 1)) OVER (), 2)         AS pct_of_all_1star
FROM (
    SELECT review_score,
           CASE WHEN delay_days <= -7 THEN '1. Early 7+ days'
                WHEN delay_days <= 0  THEN '2. On time (0-6 days early)'
                WHEN delay_days <= 3  THEN '3. Late 1-3 days'
                WHEN delay_days <= 7  THEN '4. Late 4-7 days'
                WHEN delay_days <= 14 THEN '5. Late 8-14 days'
                ELSE                       '6. Late 15+ days' END AS bucket
    FROM v_delivered_base
) b
GROUP BY bucket
ORDER BY bucket;

-- ---------------------------------------------------------------------
-- AQ5. Month-over-month change with LAG (GMV, orders, on-time, 1-star)
--      plus a 3-month moving average of on-time %
-- ---------------------------------------------------------------------
SELECT order_month,
       orders,
       gmv,
       ROUND(100 * (gmv - LAG(gmv) OVER w) / LAG(gmv) OVER w, 2)          AS gmv_mom_pct,
       ROUND(100 * (orders - LAG(orders) OVER w) / LAG(orders) OVER w, 2) AS orders_mom_pct,
       on_time_pct,
       ROUND(on_time_pct - LAG(on_time_pct) OVER w, 2)                    AS on_time_change_pp,
       pct_1star,
       ROUND(pct_1star - LAG(pct_1star) OVER w, 2)                        AS pct_1star_change_pp,
       ROUND(AVG(on_time_pct) OVER (ORDER BY order_month
                                    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2)
                                                                          AS on_time_3m_avg
FROM v_monthly_kpis
WINDOW w AS (ORDER BY order_month)
ORDER BY order_month;

-- ---------------------------------------------------------------------
-- AQ6. Pareto of late orders by seller
-- 6a. Top 20 sellers by late orders with cumulative share
-- ---------------------------------------------------------------------
SELECT seller_rank, seller_id, late_orders,
       pct_of_late, cum_pct_late, cum_pct_sellers
FROM v_seller_late_pareto
ORDER BY seller_rank
LIMIT 20;

-- 6b. How many sellers account for 80% of all late orders?
SELECT MIN(seller_rank)                                   AS sellers_for_80pct_of_late,
       MAX(n_sellers)                                     AS sellers_with_late_orders,
       ROUND(100 * MIN(seller_rank) / MAX(n_sellers), 2)  AS pct_of_late_sellers,
       (SELECT COUNT(DISTINCT seller_id) FROM v_seller_orders) AS all_active_sellers
FROM v_seller_late_pareto
WHERE cum_pct_late >= 80;

-- ---------------------------------------------------------------------
-- AQ7. First vs repeat customer experience
-- 7a. First orders compared with repeat orders
-- ---------------------------------------------------------------------
SELECT CASE WHEN customer_order_seq = 1 THEN 'First order'
            ELSE 'Repeat order' END                   AS order_type,
       COUNT(*)                                       AS orders,
       ROUND(AVG(order_value), 2)                     AS aov,
       ROUND(100 * AVG(is_on_time), 2)                AS on_time_pct,
       ROUND(AVG(delivery_days), 1)                   AS avg_delivery_days,
       ROUND(AVG(review_score), 2)                    AS avg_review_score,
       ROUND(100 * AVG(review_score = 1), 2)          AS pct_1star
FROM v_delivered_base
GROUP BY order_type;

-- 7b. Repeat rate by the review score given on the FIRST order
SELECT f.review_score                                 AS first_order_score,
       COUNT(*)                                       AS customers,
       SUM(c.n_orders > 1)                            AS repeat_customers,
       ROUND(100 * SUM(c.n_orders > 1) / COUNT(*), 2) AS repeat_rate_pct
FROM (
    SELECT customer_unique_id, review_score
    FROM v_delivered_base
    WHERE customer_order_seq = 1
      AND review_score IS NOT NULL
) f
JOIN (
    SELECT customer_unique_id, COUNT(*) AS n_orders
    FROM v_delivered_base
    GROUP BY customer_unique_id
) c ON c.customer_unique_id = f.customer_unique_id
GROUP BY f.review_score
ORDER BY f.review_score;

-- 7c. For repeat orders: score of the previous order vs score of this one (LAG)
SELECT COUNT(*)                          AS repeat_orders_compared,
       ROUND(AVG(prev_score), 2)         AS avg_previous_order_score,
       ROUND(AVG(review_score), 2)       AS avg_repeat_order_score
FROM (
    SELECT customer_order_seq,
           review_score,
           LAG(review_score) OVER (PARTITION BY customer_unique_id
                                   ORDER BY order_ts) AS prev_score
    FROM v_delivered_base
) t
WHERE customer_order_seq > 1
  AND prev_score   IS NOT NULL
  AND review_score IS NOT NULL;

-- =====================================================================
-- PART C : PERFORMANCE TUNING (EXPLAIN + INDEXES)
-- Workflow: measure BEFORE -> add indexes -> measure AFTER.
-- Note the "Duration" shown in the Workbench Output panel each time.
-- =====================================================================

-- C1. See which indexes already exist (skip any that are listed here)
SHOW INDEX FROM order_items;
SHOW INDEX FROM orders_delivered;
SHOW INDEX FROM customers;
SHOW INDEX FROM reviews_clean;
SHOW INDEX FROM products;
SHOW INDEX FROM sellers;

-- C2. BEFORE: execution plan and real timing of a heavy query
--     Look at: type = ALL (full scan), large "rows", Using temporary,
--     Using filesort, and the actual time in EXPLAIN ANALYZE.
EXPLAIN
SELECT seller_id, COUNT(*) AS late_orders
FROM v_seller_orders
WHERE is_on_time = 0
GROUP BY seller_id;

EXPLAIN ANALYZE
SELECT seller_id, COUNT(*) AS late_orders
FROM v_seller_orders
WHERE is_on_time = 0
GROUP BY seller_id;

-- C3. Add indexes on the join columns.
--     (col(32)) is a prefix index: it works for VARCHAR and for TEXT
--     columns; Olist IDs are 32 characters long.
--     "Duplicate key name" or an existing PRIMARY KEY means it is already
--     covered, so just skip that line.
CREATE INDEX idx_oi_order     ON order_items     (order_id(32));
CREATE INDEX idx_oi_seller    ON order_items     (seller_id(32));
CREATE INDEX idx_oi_product   ON order_items     (product_id(32));
CREATE INDEX idx_od_order     ON orders_delivered (order_id(32));
CREATE INDEX idx_od_customer  ON orders_delivered (customer_id(32));
CREATE INDEX idx_cust_id      ON customers       (customer_id(32));
CREATE INDEX idx_cust_unique  ON customers       (customer_unique_id(32));
CREATE INDEX idx_rev_order    ON reviews_clean   (order_id(32));
CREATE INDEX idx_prod_id      ON products        (product_id(32));
CREATE INDEX idx_sellers_id   ON sellers         (seller_id(32));

-- Refresh table statistics so the optimizer uses the new indexes well
ANALYZE TABLE order_items, orders_delivered, customers,
              reviews_clean, products, sellers;

-- C4. AFTER: run the same two statements again and compare
EXPLAIN
SELECT seller_id, COUNT(*) AS late_orders
FROM v_seller_orders
WHERE is_on_time = 0
GROUP BY seller_id;

EXPLAIN ANALYZE
SELECT seller_id, COUNT(*) AS late_orders
FROM v_seller_orders
WHERE is_on_time = 0
GROUP BY seller_id;

-- C5. Optional: materialise the heavy base view.
--     v_delivered_base contains a window function (ROW_NUMBER), so MySQL
--     recomputes it on every call. A real table is computed once.
DROP TABLE IF EXISTS t_delivered_base;
CREATE TABLE t_delivered_base AS
SELECT * FROM v_delivered_base;

CREATE INDEX idx_tdb_order    ON t_delivered_base (order_id(32));
CREATE INDEX idx_tdb_customer ON t_delivered_base (customer_unique_id(32));
CREATE INDEX idx_tdb_month    ON t_delivered_base (order_month);

-- Timing comparison: same logic, view vs materialised table
SELECT COUNT(*) AS rows_joined, ROUND(AVG(b.is_on_time), 4) AS on_time_share
FROM v_delivered_base b
JOIN order_items oi ON oi.order_id = b.order_id;

SELECT COUNT(*) AS rows_joined, ROUND(AVG(b.is_on_time), 4) AS on_time_share
FROM t_delivered_base b
JOIN order_items oi ON oi.order_id = b.order_id;

-- ---------------------------------------------------------------------
-- Step 2. Materialise the delivered-orders base (computed once)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS t_delivered_base;
CREATE TABLE t_delivered_base AS
SELECT * FROM v_delivered_base;
 
CREATE INDEX idx_tdb_order    ON t_delivered_base (order_id(32));
CREATE INDEX idx_tdb_customer ON t_delivered_base (customer_unique_id(32));
CREATE INDEX idx_tdb_month    ON t_delivered_base (order_month);
 
-- Sanity check: must return 96470
SELECT COUNT(*) AS rows_in_t_delivered_base FROM t_delivered_base;

-- ---------------------------------------------------------------------
-- Step 3. Materialise the seller-order table (built from the base table)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS t_seller_orders;
CREATE TABLE t_seller_orders AS
SELECT oi.seller_id,
       s.seller_state,
       oi.order_id,
       SUM(oi.price)                    AS seller_gmv,
       MAX(b.order_month)               AS order_month,
       MAX(b.is_on_time)                AS is_on_time,
       MAX(b.delay_days)                AS delay_days,
       MAX(b.delivery_days)             AS delivery_days,
       MAX(b.review_score)              AS review_score,
       MAX(TIMESTAMPDIFF(HOUR, od.order_approved_at,
                               od.order_delivered_carrier_date)) / 24 AS handling_days
FROM order_items oi
JOIN t_delivered_base    b  ON b.order_id  = oi.order_id
JOIN orders_delivered    od ON od.order_id = oi.order_id
JOIN sellers             s  ON s.seller_id = oi.seller_id
GROUP BY oi.seller_id, s.seller_state, oi.order_id;
 
CREATE INDEX idx_tso_seller ON t_seller_orders (seller_id(32));
CREATE INDEX idx_tso_order  ON t_seller_orders (order_id(32));
 
-- Sanity check: row count should match SELECT COUNT(*) from the old view
SELECT COUNT(*) AS rows_in_t_seller_orders FROM t_seller_orders;

-- ---------------------------------------------------------------------
-- Step 4. Point the views at the tables
--         v_seller_scorecard and v_seller_late_pareto already read from
--         v_seller_orders, so they become fast automatically.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_seller_orders AS
SELECT * FROM t_seller_orders;
 
-- Optional but recommended: also speed up every query on the base view
-- (the dataset is static, so the stored copy does not go stale)
CREATE OR REPLACE VIEW v_delivered_base AS
SELECT * FROM t_delivered_base;

CREATE OR REPLACE VIEW v_delay_buckets AS
SELECT
  order_id,
  customer_state,
  review_score,
  delay_days,  -- apne column ka asli naam use karo
  CASE
    WHEN delay_days <= 0  THEN '1. On time / Early'
    WHEN delay_days <= 3  THEN '2. 1-3 days late'
    WHEN delay_days <= 7  THEN '3. 4-7 days late'
    ELSE                       '4. 8+ days late'
  END AS delay_bucket
FROM t_delivered_base;


