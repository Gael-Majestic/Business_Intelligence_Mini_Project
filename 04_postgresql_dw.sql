-- ============================================================
-- DMS580S Mini Project 2026
-- OLAP System: PostgreSQL Data Warehouse
-- ============================================================

-- Create database (run as superuser before connecting)
-- CREATE DATABASE electronics_dw;
-- \c electronics_dw

-- ============================================================
-- SECTION 1 — CORE DW TABLES (required by project)
-- ============================================================

-- ------------------------------------------------------------
-- Table: orders_dw
-- Source: MySQL via ETL
-- ------------------------------------------------------------
DROP TABLE IF EXISTS customer_analytics;
DROP TABLE IF EXISTS orders_dw;
DROP TABLE IF EXISTS customer_activity;

CREATE TABLE orders_dw (
    order_id      INT           PRIMARY KEY,
    customer_name VARCHAR(100)  NOT NULL,
    product       VARCHAR(100)  NOT NULL,
    category      VARCHAR(50),
    brand         VARCHAR(50),
    quantity      INT           NOT NULL DEFAULT 1,
    amount        NUMERIC(10,2) NOT NULL,
    order_date    DATE          NOT NULL,
    status        VARCHAR(20)   DEFAULT 'Completed',
    city          VARCHAR(50),
    country       VARCHAR(50)
);

-- ------------------------------------------------------------
-- Table: customer_activity
-- Source: MongoDB via ETL (_id removed, timestamp standardized)
-- ------------------------------------------------------------
CREATE TABLE customer_activity (
    session_id    VARCHAR(20),
    customer_name VARCHAR(100)  NOT NULL,
    product       VARCHAR(100)  NOT NULL,
    activity      VARCHAR(20)   NOT NULL
                  CHECK (activity IN ('Viewed', 'Added to Cart', 'Purchased')),
    device        VARCHAR(20),
    timestamp     TIMESTAMP     NOT NULL
);

-- ------------------------------------------------------------
-- Table: customer_analytics  (integrated fact table)
-- Built by joining orders_dw and customer_activity
-- ------------------------------------------------------------
CREATE TABLE customer_analytics (
    analytics_id        SERIAL        PRIMARY KEY,
    customer_name       VARCHAR(100)  NOT NULL,
    product             VARCHAR(100)  NOT NULL,
    activity            VARCHAR(20)   NOT NULL,
    amount              NUMERIC(10,2),
    order_date          DATE,
    activity_timestamp  TIMESTAMP
);

-- ============================================================
-- SECTION 2 — STAR SCHEMA DIMENSION + FACT TABLES
-- These represent the analytical model diagrammed in the report
-- ============================================================

DROP TABLE IF EXISTS fact_sales         CASCADE;
DROP TABLE IF EXISTS dim_customer       CASCADE;
DROP TABLE IF EXISTS dim_product        CASCADE;
DROP TABLE IF EXISTS dim_time           CASCADE;
DROP TABLE IF EXISTS dim_activity_type  CASCADE;

CREATE TABLE dim_customer (
    customer_key  SERIAL       PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email         VARCHAR(100),
    city          VARCHAR(50),
    country       VARCHAR(50)
);

CREATE TABLE dim_product (
    product_key  SERIAL       PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category     VARCHAR(50),
    brand        VARCHAR(50),
    unit_price   NUMERIC(10,2)
);

CREATE TABLE dim_time (
    time_key    SERIAL  PRIMARY KEY,
    full_date   DATE    NOT NULL UNIQUE,
    day         INT,
    month       INT,
    month_name  VARCHAR(10),
    quarter     INT,
    year        INT,
    day_of_week VARCHAR(10)
);

CREATE TABLE dim_activity_type (
    activity_key  SERIAL      PRIMARY KEY,
    activity_type VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE fact_sales (
    sale_id      SERIAL        PRIMARY KEY,
    customer_key INT           REFERENCES dim_customer(customer_key),
    product_key  INT           REFERENCES dim_product(product_key),
    time_key     INT           REFERENCES dim_time(time_key),
    activity_key INT           REFERENCES dim_activity_type(activity_key),
    quantity     INT,
    amount       NUMERIC(10,2)
);

-- ============================================================
-- SECTION 3 — DATA INTEGRATION
-- Populate customer_analytics after ETL loads base tables
-- ============================================================

INSERT INTO customer_analytics
    (customer_name, product, activity, amount, order_date, activity_timestamp)
SELECT
    o.customer_name,
    o.product,
    a.activity,
    o.amount,
    o.order_date,
    a.timestamp
FROM  orders_dw        o
JOIN  customer_activity a
   ON o.customer_name = a.customer_name
  AND o.product        = a.product;

-- ============================================================
-- SECTION 4 — ANALYTICAL QUERIES (minimum 5)
-- ============================================================

-- ── Query 1: Total revenue by product category ──────────────
-- Business question: Which product category generates the most revenue?
SELECT
    category,
    COUNT(order_id)          AS total_orders,
    SUM(amount)              AS total_revenue,
    ROUND(AVG(amount), 2)   AS avg_order_value
FROM  orders_dw
GROUP BY category
ORDER BY total_revenue DESC;

-- ── Query 2: Top 5 products by total revenue ────────────────
-- Business question: Which individual products drive the most sales?
SELECT
    product,
    brand,
    SUM(quantity)          AS units_sold,
    SUM(amount)            AS total_revenue,
    ROUND(AVG(amount), 2) AS avg_sale_price
FROM  orders_dw
GROUP BY product, brand
ORDER BY total_revenue DESC
LIMIT 5;

-- ── Query 3: Monthly revenue trend (Jan–Apr 2026) ───────────
-- Business question: How is revenue growing month over month?
SELECT
    TO_CHAR(order_date, 'YYYY-MM')           AS month,
    COUNT(order_id)                          AS orders_placed,
    SUM(amount)                              AS monthly_revenue,
    SUM(SUM(amount)) OVER (
        ORDER BY TO_CHAR(order_date, 'YYYY-MM')
    )                                        AS cumulative_revenue
FROM  orders_dw
GROUP BY TO_CHAR(order_date, 'YYYY-MM')
ORDER BY month;

-- ── Query 4: Customer activity funnel analysis ──────────────
-- Business question: What percentage of browsing converts to purchase?
SELECT
    ca.activity,
    COUNT(*)                                              AS total_events,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1
    )                                                    AS pct_of_total
FROM  customer_activity ca
GROUP BY ca.activity
ORDER BY total_events DESC;

-- ── Query 5: Top customers by total spend ───────────────────
-- Business question: Who are the highest-value customers?
SELECT
    o.customer_name,
    o.country,
    COUNT(o.order_id)           AS total_orders,
    SUM(o.amount)               AS total_spent,
    ROUND(AVG(o.amount), 2)    AS avg_order_value
FROM  orders_dw o
GROUP BY o.customer_name, o.country
ORDER BY total_spent DESC
LIMIT 10;

-- ── Query 6: Product engagement vs conversion ───────────────
-- Business question: Which products are viewed most but convert least?
SELECT
    a.product,
    SUM(CASE WHEN a.activity = 'Viewed'        THEN 1 ELSE 0 END) AS views,
    SUM(CASE WHEN a.activity = 'Added to Cart' THEN 1 ELSE 0 END) AS cart_adds,
    SUM(CASE WHEN a.activity = 'Purchased'     THEN 1 ELSE 0 END) AS purchases,
    ROUND(
        SUM(CASE WHEN a.activity = 'Purchased' THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(SUM(CASE WHEN a.activity = 'Viewed' THEN 1 ELSE 0 END), 0),
        1
    )                                                              AS conversion_rate_pct
FROM  customer_activity a
GROUP BY a.product
ORDER BY views DESC;

-- ── Query 7: Revenue breakdown by country ───────────────────
-- Business question: How does performance differ between DRC and South Africa?
SELECT
    country,
    COUNT(order_id)   AS total_orders,
    SUM(amount)       AS total_revenue,
    COUNT(DISTINCT customer_name) AS unique_customers
FROM  orders_dw
GROUP BY country
ORDER BY total_revenue DESC;

-- ── Query 8: Integrated view — customers who viewed then purchased ──
-- Business question: Identify customers in the full purchase funnel.
SELECT DISTINCT
    ca.customer_name,
    ca.product,
    ca.amount,
    ca.order_date,
    ca.activity,
    ca.activity_timestamp
FROM  customer_analytics ca
WHERE ca.activity = 'Purchased'
ORDER BY ca.amount DESC;
