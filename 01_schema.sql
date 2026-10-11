-- =====================================================================
-- Olist E-Commerce | 01_schema.sql | Phase 1: Database design (MySQL 8)
-- =====================================================================
DROP DATABASE IF EXISTS olist;
CREATE DATABASE olist CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE olist;

-- ---------- Lookup / dimension tables ----------
CREATE TABLE category_translation (
    product_category_name          VARCHAR(80) NOT NULL,
    product_category_name_english  VARCHAR(80) NOT NULL,
    PRIMARY KEY (product_category_name)
);

CREATE TABLE customers (
    customer_id               CHAR(32)    NOT NULL,   -- one per ORDER (changes every order)
    customer_unique_id        CHAR(32)    NOT NULL,   -- the real person (use for repeat-rate!)
    customer_zip_code_prefix  CHAR(5)     NULL,
    customer_city             VARCHAR(60) NULL,
    customer_state            CHAR(2)     NULL,
    PRIMARY KEY (customer_id),
    KEY idx_customers_unique (customer_unique_id),
    KEY idx_customers_state  (customer_state)
);

CREATE TABLE sellers (
    seller_id               CHAR(32)    NOT NULL,
    seller_zip_code_prefix  CHAR(5)     NULL,
    seller_city             VARCHAR(60) NULL,
    seller_state            CHAR(2)     NULL,
    PRIMARY KEY (seller_id),
    KEY idx_sellers_state (seller_state)
);

CREATE TABLE products (
    product_id                  CHAR(32)     NOT NULL,
    product_category_name       VARCHAR(80)  NULL,   -- ~610 NULLs in raw data
    product_name_length         INT          NULL,   -- raw header is misspelled "lenght"
    product_description_length  INT          NULL,
    product_photos_qty          INT          NULL,
    product_weight_g            INT          NULL,
    product_length_cm           INT          NULL,
    product_height_cm           INT          NULL,
    product_width_cm            INT          NULL,
    PRIMARY KEY (product_id),
    KEY idx_products_category (product_category_name)
    -- No FK to category_translation on purpose: some raw categories
    -- have no translation row and NULL categories exist. Handle in Phase 2.
);

-- ---------- Fact tables ----------
CREATE TABLE orders (
    order_id                       CHAR(32)    NOT NULL,
    customer_id                    CHAR(32)    NOT NULL,
    order_status                   VARCHAR(20) NOT NULL,
    order_purchase_timestamp       DATETIME    NULL,
    order_approved_at              DATETIME    NULL,
    order_delivered_carrier_date   DATETIME    NULL,
    order_delivered_customer_date  DATETIME    NULL,
    order_estimated_delivery_date  DATETIME    NULL,
    PRIMARY KEY (order_id),
    KEY idx_orders_customer (customer_id),
    KEY idx_orders_status   (order_status),
    KEY idx_orders_purchase (order_purchase_timestamp),
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

CREATE TABLE order_items (
    order_id             CHAR(32)       NOT NULL,
    order_item_id        INT            NOT NULL,   -- 1,2,3... line number within the order
    product_id           CHAR(32)       NOT NULL,
    seller_id            CHAR(32)       NOT NULL,
    shipping_limit_date  DATETIME       NULL,
    price                DECIMAL(10,2)  NOT NULL,
    freight_value        DECIMAL(10,2)  NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    KEY idx_items_product (product_id),
    KEY idx_items_seller  (seller_id),
    CONSTRAINT fk_items_order   FOREIGN KEY (order_id)   REFERENCES orders   (order_id),
    CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products (product_id),
    CONSTRAINT fk_items_seller  FOREIGN KEY (seller_id)  REFERENCES sellers  (seller_id)
);

CREATE TABLE order_payments (
    order_id              CHAR(32)       NOT NULL,
    payment_sequential    INT            NOT NULL,
    payment_type          VARCHAR(20)    NOT NULL,
    payment_installments  INT            NOT NULL,
    payment_value         DECIMAL(10,2)  NOT NULL,
    PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_pay_order FOREIGN KEY (order_id) REFERENCES orders (order_id)
);

CREATE TABLE order_reviews (
    review_pk                BIGINT        NOT NULL AUTO_INCREMENT,  -- surrogate key (see note)
    review_id                CHAR(32)      NOT NULL,
    order_id                 CHAR(32)      NOT NULL,
    review_score             TINYINT       NOT NULL,
    review_comment_title     VARCHAR(255)  NULL,
    review_comment_message   TEXT          NULL,
    review_creation_date     DATETIME      NULL,
    review_answer_timestamp  DATETIME      NULL,
    PRIMARY KEY (review_pk),
    KEY idx_reviews_order (order_id),
    KEY idx_reviews_id    (review_id),
    CONSTRAINT fk_reviews_order FOREIGN KEY (order_id) REFERENCES orders (order_id)
    -- NOTE: review_id is NOT unique in the raw file, and some orders have
    -- more than one review. That is the "duplicate reviews" issue for Phase 2.
);

-- ---------- Optional (1M rows, only needed for maps/coordinates) ----------
CREATE TABLE geolocation (
    geolocation_zip_code_prefix  CHAR(5)       NOT NULL,
    geolocation_lat              DECIMAL(10,7) NULL,
    geolocation_lng              DECIMAL(10,7) NULL,
    geolocation_city             VARCHAR(60)   NULL,
    geolocation_state            CHAR(2)       NULL,
    KEY idx_geo_zip (geolocation_zip_code_prefix)
);
