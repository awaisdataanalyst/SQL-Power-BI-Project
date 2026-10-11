-- =====================================================================
-- Phase 4 : KPI Analysis  |  Olist E-Commerce (MySQL 8)
-- Part A  : Build views (run once)
-- Part B  : Business questions 1-8 (run one by one)
-- KPI definitions
--   GMV            = SUM(price + freight_value) of delivered orders
--   Orders         = number of delivered orders
--   AOV            = GMV / Orders
--   On-time %      = delivered on or before the estimated delivery date
--   Delivery days  = purchase date -> customer delivery date
--   Delay days     = delivery date - estimated date (positive = late)
--   % 1-star       = share of reviewed orders with review_score = 1
--   Repeat rate    = customers with 2+ delivered orders / all customers
--                    (uses customer_unique_id, NOT customer_id)
-- Reliable window for trends: 2017-01 to 2018-08 (see Phase 3 findings)
-- =====================================================================
USE olist_ecommerce;
-- =====================================================================
-- PART A : VIEWS
-- =====================================================================

-- A1. One row per order with item value, freight and total order value
CREATE OR REPLACE VIEW v_order_values AS
SELECT order_id,
       COUNT(*)                      AS items,
       SUM(price)                    AS items_value,
       SUM(freight_value)            AS freight_value,
       SUM(price + freight_value)    AS order_value
FROM order_items
GROUP BY order_id;

-- A2. One review score per order (lowest score if an order has several)
CREATE OR REPLACE VIEW v_review_per_order AS
SELECT order_id,
       MIN(review_score) AS review_score
FROM reviews_clean
GROUP BY order_id;

-- A3. Base view: one row per delivered order with every KPI input
CREATE OR REPLACE VIEW v_delivered_base AS
SELECT od.order_id,
       c.customer_unique_id,
       c.customer_state,
       od.order_purchase_timestamp                             AS order_ts,
       DATE_FORMAT(od.order_purchase_timestamp, '%Y-%m')       AS order_month,
       v.items,
       v.order_value,
       DATEDIFF(od.order_delivered_customer_date,
                od.order_purchase_timestamp)                   AS delivery_days,
       DATEDIFF(od.order_delivered_customer_date,
                od.order_estimated_delivery_date)              AS delay_days,
       CASE WHEN DATEDIFF(od.order_delivered_customer_date,
                          od.order_estimated_delivery_date) <= 0
            THEN 1 ELSE 0 END                                  AS is_on_time,
       r.review_score,
       ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id
                          ORDER BY od.order_purchase_timestamp) AS customer_order_seq
FROM orders_delivered od
JOIN customers        c ON c.customer_id = od.customer_id
JOIN v_order_values   v ON v.order_id    = od.order_id
LEFT JOIN v_review_per_order r ON r.order_id = od.order_id;

-- A4. Monthly KPI view (GMV, orders, AOV, on-time %, delivery days,
--     review score, % 1-star, repeat-order share)
CREATE OR REPLACE VIEW v_monthly_kpis AS
SELECT order_month,
       COUNT(*)                                       AS orders,
       ROUND(SUM(order_value), 2)                     AS gmv,
       ROUND(AVG(order_value), 2)                     AS aov,
       ROUND(100 * AVG(is_on_time), 2)                AS on_time_pct,
       ROUND(AVG(delivery_days), 1)                   AS avg_delivery_days,
       ROUND(AVG(review_score), 2)                    AS avg_review_score,
       ROUND(100 * AVG(review_score = 1), 2)          AS pct_1star,
       ROUND(100 * AVG(customer_order_seq > 1), 2)    AS repeat_order_pct
FROM v_delivered_base
WHERE order_month BETWEEN '2017-01' AND '2018-08'
GROUP BY order_month;

-- A5. Overall repeat rate (customer level)
CREATE OR REPLACE VIEW v_repeat_rate AS
SELECT COUNT(*)                                   AS unique_customers,
       SUM(n_orders > 1)                          AS repeat_customers,
       ROUND(100 * SUM(n_orders > 1) / COUNT(*), 2) AS repeat_rate_pct
FROM (
    SELECT customer_unique_id, COUNT(*) AS n_orders
    FROM v_delivered_base
    GROUP BY customer_unique_id
) t;

-- Quick check that the views work
SELECT * FROM v_monthly_kpis ORDER BY order_month;
SELECT * FROM v_repeat_rate;

-- =====================================================================
-- PART B : BUSINESS QUESTIONS
-- =====================================================================
 
-- ---------------------------------------------------------------------
-- BQ1. How are GMV, orders and AOV trending month by month?
-- ---------------------------------------------------------------------
SELECT order_month, orders, gmv, aov
FROM v_monthly_kpis
ORDER BY order_month;

-- ---------------------------------------------------------------------
-- BQ2. What are the overall headline KPIs?
-- ---------------------------------------------------------------------
SELECT COUNT(*)                                AS delivered_orders,
       ROUND(SUM(order_value), 2)              AS gmv,
       ROUND(AVG(order_value), 2)              AS aov,
       ROUND(100 * AVG(is_on_time), 2)         AS on_time_pct,
       ROUND(AVG(delivery_days), 1)            AS avg_delivery_days,
       ROUND(AVG(review_score), 2)             AS avg_review_score,
       ROUND(100 * AVG(review_score = 1), 2)   AS pct_1star
FROM v_delivered_base;

-- ---------------------------------------------------------------------
-- BQ3. How many orders arrive late and by how much?
-- ---------------------------------------------------------------------
SELECT CASE WHEN is_on_time = 1 THEN 'On time' ELSE 'Late' END AS delivery_status,
       COUNT(*)                                                AS orders,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)        AS pct_of_orders,
       ROUND(AVG(delay_days), 1)                               AS avg_delay_days,
       ROUND(AVG(delivery_days), 1)                            AS avg_delivery_days
FROM v_delivered_base
GROUP BY is_on_time;

-- ---------------------------------------------------------------------
-- BQ4. Does late delivery hurt customer satisfaction?
--      (review score and % 1-star by delay bucket)
-- ---------------------------------------------------------------------
SELECT bucket,
       COUNT(*)                                AS orders,
       ROUND(AVG(review_score), 2)             AS avg_review_score,
       ROUND(100 * AVG(review_score = 1), 2)   AS pct_1star
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
-- BQ5. Which states have the weakest delivery performance?
--      (states with 500+ delivered orders, worst on-time % first)
-- ---------------------------------------------------------------------
SELECT customer_state,
       COUNT(*)                                AS orders,
       ROUND(100 * AVG(is_on_time), 2)         AS on_time_pct,
       ROUND(AVG(delivery_days), 1)            AS avg_delivery_days,
       ROUND(AVG(review_score), 2)             AS avg_review_score,
       ROUND(100 * AVG(review_score = 1), 2)   AS pct_1star
FROM v_delivered_base
GROUP BY customer_state
HAVING COUNT(*) >= 500
ORDER BY on_time_pct ASC
LIMIT 10;

-- ---------------------------------------------------------------------
-- BQ6. Which product categories get the most 1-star reviews?
--      (categories with 300+ delivered orders)
-- ---------------------------------------------------------------------
SELECT COALESCE(t.product_category_name_english,
                p.product_category_name,
                'unknown')                      AS category,
       COUNT(DISTINCT b.order_id)               AS orders,
       ROUND(100 * AVG(b.is_on_time), 2)        AS on_time_pct,
       ROUND(AVG(b.review_score), 2)            AS avg_review_score,
       ROUND(100 * AVG(b.review_score = 1), 2)  AS pct_1star
FROM v_delivered_base b
JOIN order_items oi  ON oi.order_id   = b.order_id
JOIN products p      ON p.product_id  = oi.product_id
LEFT JOIN category_translation t
                     ON t.product_category_name = p.product_category_name
GROUP BY category
HAVING COUNT(DISTINCT b.order_id) >= 300
ORDER BY pct_1star DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- BQ7. Where does the time go? (stage breakdown, on-time vs late orders)
--      approval = purchase -> approved, seller = approved -> handed to
--      carrier, carrier = handed to carrier -> delivered to customer
-- ---------------------------------------------------------------------
SELECT CASE WHEN b.is_on_time = 1 THEN 'On time' ELSE 'Late' END AS delivery_status,
       COUNT(*) AS orders,
       ROUND(AVG(TIMESTAMPDIFF(HOUR, od.order_purchase_timestamp,
                                     od.order_approved_at)) / 24, 2)          AS approval_days,
       ROUND(AVG(TIMESTAMPDIFF(HOUR, od.order_approved_at,
                                     od.order_delivered_carrier_date)) / 24, 2) AS seller_handling_days,
       ROUND(AVG(TIMESTAMPDIFF(HOUR, od.order_delivered_carrier_date,
                                     od.order_delivered_customer_date)) / 24, 2) AS carrier_days
FROM v_delivered_base b
JOIN orders_delivered od ON od.order_id = b.order_id
WHERE od.order_approved_at IS NOT NULL
  AND od.order_delivered_carrier_date IS NOT NULL
GROUP BY b.is_on_time;

-- ---------------------------------------------------------------------
-- BQ8. How many customers come back, and does a late first order
--      reduce the chance of a repeat purchase?
-- ---------------------------------------------------------------------
-- 8a. Overall repeat rate
SELECT * FROM v_repeat_rate;

-- 8b. Repeat rate split by first-order delivery status
SELECT CASE WHEN f.is_on_time = 1 THEN 'First order on time'
            ELSE 'First order late' END                      AS first_order_status,
       COUNT(*)                                              AS customers,
       SUM(c.n_orders > 1)                                   AS repeat_customers,
       ROUND(100 * SUM(c.n_orders > 1) / COUNT(*), 2)        AS repeat_rate_pct
FROM (
    SELECT customer_unique_id, is_on_time
    FROM v_delivered_base
    WHERE customer_order_seq = 1
) f
JOIN (
    SELECT customer_unique_id, COUNT(*) AS n_orders
    FROM v_delivered_base
    GROUP BY customer_unique_id
) c ON c.customer_unique_id = f.customer_unique_id
GROUP BY f.is_on_time;

 