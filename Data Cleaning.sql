-- =====================================================================
-- Phase 2 : Data Cleaning  |  Olist E-Commerce (MySQL 8)
-- Rule: never modify the RAW tables. Only create *_clean tables.
-- After each step, record the results in cleaning_log.md.
-- =====================================================================
USE olist_ecommerce;

-- ---------------------------------------------------------------------
-- STEP 0 : BASELINE ROW COUNTS  (the "Before" column in the log)
-- ---------------------------------------------------------------------
SELECT 'orders' AS tbl, COUNT(*) AS n FROM orders
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation;
-- NOTE: if your table names differ (e.g. reviews), adjust them here and below.

-- ---------------------------------------------------------------------
-- STEP 1 : NULL AUDIT  (inspection only, nothing is deleted yet)
-- ---------------------------------------------------------------------
-- 1a. NULL dates by order status
SELECT order_status,
       COUNT(*)                                        AS total,
       SUM(order_approved_at IS NULL)                  AS null_approved,
       SUM(order_delivered_carrier_date IS NULL)       AS null_carrier,
       SUM(order_delivered_customer_date IS NULL)      AS null_delivered
FROM orders
GROUP BY order_status
ORDER BY total DESC;

-- 1b. SUSPICIOUS: status is 'delivered' but the delivery date is NULL
SELECT order_id, order_status, order_approved_at, order_delivered_customer_date
FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL;

-- 1c. SUSPICIOUS: status is 'delivered' but the approval date is NULL
SELECT COUNT(*) AS delivered_but_no_approval
FROM orders
WHERE order_status = 'delivered' AND order_approved_at IS NULL;

-- 1d. Non-delivered orders that still have a delivery date (should be ~0)
SELECT order_status, COUNT(*) AS has_delivery_date_but_not_delivered
FROM orders
WHERE order_status <> 'delivered' AND order_delivered_customer_date IS NOT NULL
GROUP BY order_status;

-- ---------------------------------------------------------------------
-- STEP 2 : ORDERS_CLEAN  (with flags, no rows deleted)
-- Idea: keep every order, but flag each problem.
-- A separate table (orders_delivered) is built later for delivery analysis.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS orders_clean;
CREATE TABLE orders_clean AS
SELECT o.*,

       -- status group
       CASE WHEN order_status IN ('canceled','unavailable') THEN 1 ELSE 0 END AS is_cancelled_or_unavailable,

       -- missing date flags
       (order_approved_at IS NULL)                AS flag_null_approved,
       (order_delivered_customer_date IS NULL)    AS flag_null_delivered,

       -- LOGIC flags (1 = problem)
       (order_approved_at < order_purchase_timestamp)                          AS flag_approved_before_purchase,
       (order_delivered_carrier_date < order_purchase_timestamp)               AS flag_carrier_before_purchase,
       (order_delivered_customer_date < order_purchase_timestamp)              AS flag_delivered_before_purchase,
       (order_delivered_customer_date < order_delivered_carrier_date)          AS flag_delivered_before_carrier,
       (order_estimated_delivery_date < order_purchase_timestamp)              AS flag_estimate_before_purchase
FROM orders o;

ALTER TABLE orders_clean ADD PRIMARY KEY (order_id);

-- Flag summary (for the log)
SELECT COUNT(*) AS total_rows,
       SUM(is_cancelled_or_unavailable)     AS cancelled_or_unavailable,
       SUM(flag_null_approved)              AS null_approved,
       SUM(flag_null_delivered)             AS null_delivered,
       SUM(flag_approved_before_purchase)   AS approved_before_purchase,
       SUM(flag_carrier_before_purchase)    AS carrier_before_purchase,
       SUM(flag_delivered_before_purchase)  AS delivered_before_purchase,
       SUM(flag_delivered_before_carrier)   AS delivered_before_carrier,
       SUM(flag_estimate_before_purchase)   AS estimate_before_purchase
FROM orders_clean;

-- ---------------------------------------------------------------------
-- STEP 3 : ORDERS_DELIVERED  (base table for delivery-performance analysis)
-- Rules:
--   * status = 'delivered'
--   * delivery date IS NOT NULL
--   * delivered_before_purchase = 0  (impossible dates are removed)
-- Note: rows where delivered_before_carrier = 1 are NOT dropped (likely a
-- timestamp-logging issue); they stay flagged only. Record this decision
-- in the log.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS orders_delivered;
CREATE TABLE orders_delivered AS
SELECT oc.*,
       DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)   AS delivery_days,
       DATEDIFF(order_estimated_delivery_date, order_purchase_timestamp)   AS estimated_days,
       -- delay_days: NEGATIVE = delivered early (this is VALID, not an error)
       DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) AS delay_days,
       CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
            THEN 1 ELSE 0 END                                              AS is_late
FROM orders_clean oc
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND flag_delivered_before_purchase = 0;

ALTER TABLE orders_delivered ADD PRIMARY KEY (order_id);

-- Sanity checks (the first two should return 0)
SELECT SUM(delivery_days < 0)  AS negative_delivery_days,
       SUM(estimated_days < 0) AS negative_estimated_days,
       COUNT(*)                AS rows_in_orders_delivered
FROM orders_delivered;

-- Early vs on-time vs late distribution (negative delay = early, informational)
SELECT SUM(delay_days < 0)  AS early,
       SUM(delay_days = 0)  AS on_time_day,
       SUM(delay_days > 0)  AS late
FROM orders_delivered;

-- ---------------------------------------------------------------------
-- STEP 4 : REVIEWS_CLEAN  (one order = one review)
-- Rule: keep the LATEST review per order_id
--       (answer timestamp DESC, then creation date, then review_pk)
-- ---------------------------------------------------------------------
-- 4a. Size of the problem
SELECT COUNT(*)                         AS total_review_rows,
       COUNT(DISTINCT order_id)         AS distinct_orders,
       COUNT(*) - COUNT(DISTINCT order_id) AS extra_rows_to_remove
FROM order_reviews;

-- 4b. Score range check (should be 1-5 only)
SELECT review_score, COUNT(*) FROM order_reviews GROUP BY review_score ORDER BY review_score;

-- 4c. Deduplicate
DROP TABLE IF EXISTS reviews_clean;
CREATE TABLE reviews_clean AS
SELECT x.*
FROM (
    SELECT r.*,
           ROW_NUMBER() OVER (
               PARTITION BY r.order_id
               ORDER BY r.review_answer_timestamp DESC,
                        r.review_creation_date DESC,
                        r.review_pk DESC
           ) AS rn
    FROM order_reviews r
) x
WHERE x.rn = 1;

ALTER TABLE reviews_clean DROP COLUMN rn;
ALTER TABLE reviews_clean ADD PRIMARY KEY (order_id);   -- fails if dedup is wrong

-- 4d. Verify
SELECT COUNT(*) AS rows_after, COUNT(DISTINCT order_id) AS distinct_orders_after FROM reviews_clean;

-- ---------------------------------------------------------------------
-- STEP 5 : PRODUCTS_CLEAN  (standardize category names)
-- ---------------------------------------------------------------------
-- 5a. Which categories are MISSING from the translation table?
SELECT p.product_category_name, COUNT(*) AS products
FROM products p
LEFT JOIN category_translation t
       ON TRIM(LOWER(p.product_category_name)) = TRIM(LOWER(t.product_category_name))
WHERE t.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY products DESC;
-- Expect: NULL categories (missing) + 2 untranslated Portuguese names.

-- 5b. Build the clean table
DROP TABLE IF EXISTS products_clean;
CREATE TABLE products_clean AS
SELECT p.*,
       CASE
         WHEN p.product_category_name IS NULL OR TRIM(p.product_category_name) = ''
              THEN 'unknown'
         WHEN t.product_category_name_english IS NOT NULL
              THEN LOWER(TRIM(t.product_category_name_english))
         -- manual fixes for untranslated names (confirm against the 5a output)
         WHEN p.product_category_name = 'pc_gamer'
              THEN 'pc_gamer'
         WHEN p.product_category_name = 'portateis_cozinha_e_preparadores_de_alimentos'
              THEN 'portable_kitchen_and_food_preparers'
         ELSE 'unknown'
       END AS category_english
FROM products p
LEFT JOIN category_translation t
       ON TRIM(LOWER(p.product_category_name)) = TRIM(LOWER(t.product_category_name));

ALTER TABLE products_clean ADD PRIMARY KEY (product_id);

-- 5c. Verify
SELECT category_english, COUNT(*) AS n FROM products_clean GROUP BY category_english ORDER BY n DESC;
SELECT COUNT(*) AS rows_after FROM products_clean;           -- must equal the raw products row count
SELECT SUM(category_english = 'unknown') AS unknown_category FROM products_clean;

-- ---------------------------------------------------------------------
-- STEP 6 : FINAL ROW-COUNT SUMMARY  (for cleaning_log.md)
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS products_clean;
CREATE TABLE products_clean AS
SELECT p.*,
       CASE
         WHEN p.product_category_name IS NULL OR TRIM(p.product_category_name) = ''
              THEN 'unknown'
         WHEN t.product_category_name_english IS NOT NULL
              THEN LOWER(TRIM(t.product_category_name_english))
         WHEN p.product_category_name = 'pc_gamer'
              THEN 'pc_gamer'
         WHEN p.product_category_name = 'portateis_cozinha_e_preparadores_de_alimentos'
              THEN 'portable_kitchen_and_food_preparers'
         ELSE 'unknown'
       END AS category_english
FROM products p
LEFT JOIN category_translation t
       ON TRIM(LOWER(p.product_category_name)) = TRIM(LOWER(t.product_category_name));

ALTER TABLE products_clean ADD PRIMARY KEY (product_id);
SELECT COUNT(*) AS rows_after FROM products_clean;
SELECT SUM(category_english = 'unknown') AS unknown_category FROM products_clean;

-- ---------------------------------------------------------------------
-- STEP 6 : FINAL ROW-COUNT SUMMARY  (for cleaning_log.md)
-- ---------------------------------------------------------------------
SELECT 'orders (raw)'        AS tbl, COUNT(*) AS n FROM orders
UNION ALL SELECT 'orders_clean',      COUNT(*) FROM orders_clean
UNION ALL SELECT 'orders_delivered',  COUNT(*) FROM orders_delivered
UNION ALL SELECT 'reviews (raw)',     COUNT(*) FROM order_reviews
UNION ALL SELECT 'reviews_clean',     COUNT(*) FROM reviews_clean
UNION ALL SELECT 'products (raw)',    COUNT(*) FROM products
UNION ALL SELECT 'products_clean',    COUNT(*) FROM products_clean;
