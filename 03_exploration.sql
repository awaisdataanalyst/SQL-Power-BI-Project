-- =====================================================================
-- Phase 3 : Exploratory SQL Analysis  |  Olist E-Commerce (MySQL 8)
-- Goal    : Understand the data before building KPIs.
--           Note down the output of every query.
-- =====================================================================
USE olist_ecommerce;

-- ---------------------------------------------------------------------
-- Q1. Row counts of all tables
-- ---------------------------------------------------------------------
SELECT 'customers'            AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'orders',               COUNT(*) FROM orders
UNION ALL SELECT 'order_items',          COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments',       COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews',        COUNT(*) FROM order_reviews
UNION ALL SELECT 'products',             COUNT(*) FROM products
UNION ALL SELECT 'sellers',              COUNT(*) FROM sellers
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation;

-- ---------------------------------------------------------------------
-- Q2. Order date range (first/last order, total span in days)
-- ---------------------------------------------------------------------
SELECT MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order,
       DATEDIFF(MAX(order_purchase_timestamp),
                MIN(order_purchase_timestamp)) AS span_days
FROM orders;

-- ---------------------------------------------------------------------
-- Q3. Orders per month (volume trend; helps spot incomplete months)
-- ---------------------------------------------------------------------
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,
       COUNT(*) AS total_orders
FROM orders
GROUP BY order_month
ORDER BY order_month;

-- ---------------------------------------------------------------------
-- Q4. Order status distribution (count and percentage)
-- ---------------------------------------------------------------------
SELECT order_status,
       COUNT(*) AS total_orders,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- ---------------------------------------------------------------------
-- Q5. Date range of delivered orders (delivery KPIs will be based on these)
-- ---------------------------------------------------------------------
SELECT MIN(order_delivered_customer_date) AS first_delivery,
       MAX(order_delivered_customer_date) AS last_delivery,
       COUNT(*)                           AS delivered_orders
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;
  
  -- ---------------------------------------------------------------------
-- Q6. Top 10 product categories by items sold (English names)
-- ---------------------------------------------------------------------
SELECT COALESCE(t.product_category_name_english,
                p.product_category_name,
                'unknown')            AS category,
       COUNT(*)                       AS items_sold,
       ROUND(SUM(oi.price), 2)        AS revenue
FROM order_items oi
JOIN products p              ON p.product_id = oi.product_id
LEFT JOIN category_translation t
                             ON t.product_category_name = p.product_category_name
GROUP BY category
ORDER BY items_sold DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q7. Top 10 product categories by revenue
-- ---------------------------------------------------------------------
SELECT COALESCE(t.product_category_name_english,
                p.product_category_name,
                'unknown')            AS category,
       ROUND(SUM(oi.price), 2)        AS revenue,
       COUNT(DISTINCT oi.order_id)    AS orders
FROM order_items oi
JOIN products p              ON p.product_id = oi.product_id
LEFT JOIN category_translation t
                             ON t.product_category_name = p.product_category_name
GROUP BY category
ORDER BY revenue DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q8. Customer state distribution (top 10 states by number of orders)
-- ---------------------------------------------------------------------
SELECT c.customer_state,
       COUNT(*) AS total_orders,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_orders
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
GROUP BY c.customer_state
ORDER BY total_orders DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q9. Seller state distribution (top 10) - where the sellers are located
-- ---------------------------------------------------------------------
SELECT seller_state,
       COUNT(*) AS total_sellers
FROM sellers
GROUP BY seller_state
ORDER BY total_sellers DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q10. Payment mix: count, total value and share by payment type
-- ---------------------------------------------------------------------
SELECT payment_type,
       COUNT(*)                         AS payments,
       ROUND(SUM(payment_value), 2)     AS total_value,
       ROUND(100 * SUM(payment_value) / SUM(SUM(payment_value)) OVER (), 2) AS pct_of_value
FROM order_payments
GROUP BY payment_type
ORDER BY total_value DESC;

-- ---------------------------------------------------------------------
-- Q11. Installments distribution (credit card payments only)
-- ---------------------------------------------------------------------
SELECT payment_installments,
       COUNT(*) AS payments
FROM order_payments
WHERE payment_type = 'credit_card'
GROUP BY payment_installments
ORDER BY payment_installments;

-- ---------------------------------------------------------------------
-- Q12. Review score distribution (from the cleaned reviews table)
-- ---------------------------------------------------------------------
SELECT review_score,
       COUNT(*) AS reviews,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM reviews_clean
GROUP BY review_score
ORDER BY review_score;

-- ---------------------------------------------------------------------
-- Q13. Items per order and order value summary
-- ---------------------------------------------------------------------
SELECT ROUND(AVG(items_in_order), 2) AS avg_items_per_order,
       MAX(items_in_order)           AS max_items,
       ROUND(AVG(order_value), 2)    AS avg_order_value,
       ROUND(MIN(order_value), 2)    AS min_order_value,
       ROUND(MAX(order_value), 2)    AS max_order_value
FROM (
    SELECT order_id,
           COUNT(*)                   AS items_in_order,
           SUM(price + freight_value) AS order_value
    FROM order_items
    GROUP BY order_id
) x;

-- ---------------------------------------------------------------------
-- Q14. Price and freight range (first look at possible outliers)
-- ---------------------------------------------------------------------
SELECT ROUND(MIN(price), 2)          AS min_price,
       ROUND(AVG(price), 2)          AS avg_price,
       ROUND(MAX(price), 2)          AS max_price,
       ROUND(AVG(freight_value), 2)  AS avg_freight,
       ROUND(MAX(freight_value), 2)  AS max_freight
FROM order_items;

-- ---------------------------------------------------------------------
-- Q15. Quick look at delivery time (days from purchase to delivery,
--      delivered orders only)
-- ---------------------------------------------------------------------
SELECT ROUND(AVG(DATEDIFF(order_delivered_customer_date,
                          order_purchase_timestamp)), 1) AS avg_delivery_days,
       MIN(DATEDIFF(order_delivered_customer_date,
                    order_purchase_timestamp))           AS min_days,
       MAX(DATEDIFF(order_delivered_customer_date,
                    order_purchase_timestamp))           AS max_days
FROM orders_delivered;

