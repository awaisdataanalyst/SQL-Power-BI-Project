-- =====================================================================
-- Olist E-Commerce | 01_verify.sql | Phase 1: Post-load checks
-- =====================================================================
USE olist_ecommerce;

-- 1) Row counts vs the standard Kaggle files
SELECT 'category_translation' AS tbl, COUNT(*) AS actual_rows, 71      AS expected_rows FROM category_translation
UNION ALL SELECT 'customers',      COUNT(*), 99441   FROM customers
UNION ALL SELECT 'sellers',        COUNT(*), 3095    FROM sellers
UNION ALL SELECT 'products',       COUNT(*), 32951   FROM products
UNION ALL SELECT 'orders',         COUNT(*), 99441   FROM orders
UNION ALL SELECT 'order_items',    COUNT(*), 112650  FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*), 103886  FROM order_payments
UNION ALL SELECT 'order_reviews',  COUNT(*), 99224   FROM order_reviews
UNION ALL SELECT 'geolocation',    COUNT(*), 1000163 FROM geolocation;

-- 2) Orphan checks (every result should be 0)
SELECT 'orders without customer' AS check_name, COUNT(*) AS bad_rows
FROM orders o LEFT JOIN customers c ON c.customer_id = o.customer_id WHERE c.customer_id IS NULL
UNION ALL
SELECT 'items without order', COUNT(*)
FROM order_items i LEFT JOIN orders o ON o.order_id = i.order_id WHERE o.order_id IS NULL
UNION ALL
SELECT 'items without product', COUNT(*)
FROM order_items i LEFT JOIN products p ON p.product_id = i.product_id WHERE p.product_id IS NULL
UNION ALL
SELECT 'items without seller', COUNT(*)
FROM order_items i LEFT JOIN sellers s ON s.seller_id = i.seller_id WHERE s.seller_id IS NULL
UNION ALL
SELECT 'payments without order', COUNT(*)
FROM order_payments p LEFT JOIN orders o ON o.order_id = p.order_id WHERE o.order_id IS NULL
UNION ALL
SELECT 'reviews without order', COUNT(*)
FROM order_reviews r LEFT JOIN orders o ON o.order_id = r.order_id WHERE o.order_id IS NULL;

-- 3) Date range sanity
SELECT MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order,
       COUNT(*) AS orders_total,
       SUM(order_delivered_customer_date IS NULL) AS no_delivery_date
FROM orders;

-- 4) Order status mix (preview of Phase 2 cleaning)
SELECT order_status, COUNT(*) AS n,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders GROUP BY order_status ORDER BY n DESC;

-- 5) Known data-quality flags to document (not fix yet; fix in Phase 2)
SELECT 'orders with >1 review' AS flag, COUNT(*) AS n
FROM (SELECT order_id FROM order_reviews GROUP BY order_id HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'review_ids repeated', COUNT(*)
FROM (SELECT review_id FROM order_reviews GROUP BY review_id HAVING COUNT(*) > 1) y
UNION ALL
SELECT 'products with NULL category', COUNT(*) FROM products WHERE product_category_name IS NULL
UNION ALL
SELECT 'categories missing translation', COUNT(DISTINCT p.product_category_name)
FROM products p LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
WHERE p.product_category_name IS NOT NULL AND t.product_category_name IS NULL;