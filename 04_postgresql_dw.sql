-- ============================================================
-- DMS580S Mini Project 2026
-- OLAP System: PostgreSQL Data Warehouse
-- ============================================================

-- With docker-compose.yml this script runs automatically, inside the
-- electronics_dw database, the first time the PostgreSQL container starts.
-- By hand (as a superuser):
--   CREATE DATABASE electronics_dw;
--   \c electronics_dw
--   \i 04_postgresql_dw.sql

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
-- (05_star_schema.html). The ETL fills them on every run:
-- dim_customer and dim_product from the MySQL master tables,
-- dim_time from the order dates, dim_activity_type with the
-- three activity values, and fact_sales with one row per order.
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
-- Populate customer_analytics after ETL loads base tables.
-- (03_etl_pipeline.py runs the same statement after each load;
-- here, on freshly created empty tables, it inserts nothing.)
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

-- ── Query 7: Revenue breakdown by country and city ──────────
-- Business question: Which markets generate the most revenue?
-- (The sample data covers South African cities only.)
SELECT
    country,
    city,
    COUNT(order_id)   AS total_orders,
    SUM(amount)       AS total_revenue,
    COUNT(DISTINCT customer_name) AS unique_customers
FROM  orders_dw
GROUP BY country, city
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

-- ============================================================
-- SECTION 5 — QUERIES ON THE STAR SCHEMA
-- The same kind of question, answered by joining the fact table
-- to its dimensions: the typical OLAP query shape.
-- ============================================================

-- ── Query 9: Revenue by quarter and product category ────────
-- Business question: How does each category perform per quarter?
SELECT
    t.year,
    t.quarter,
    p.category,
    SUM(f.quantity)  AS units_sold,
    SUM(f.amount)    AS revenue
FROM  fact_sales  f
JOIN  dim_time    t ON t.time_key    = f.time_key
JOIN  dim_product p ON p.product_key = f.product_key
GROUP BY t.year, t.quarter, p.category
ORDER BY t.year, t.quarter, revenue DESC;

-- ── Query 10: Discounts — sale price versus list price ──────
-- Business question: Were any products sold below their list price? (BR-01)
SELECT
    p.product_name,
    p.unit_price                                   AS list_price,
    ROUND(SUM(f.amount) / SUM(f.quantity), 2)      AS avg_sale_price,
    SUM(f.quantity) * p.unit_price - SUM(f.amount) AS total_discount
FROM  fact_sales  f
JOIN  dim_product p ON p.product_key = f.product_key
GROUP BY p.product_name, p.unit_price
ORDER BY total_discount DESC, p.product_name;

-- ── Query 11: Revenue by city and weekday ───────────────────
-- Business question: On which weekdays do customers in each city buy?
SELECT
    c.city,
    t.day_of_week,
    COUNT(*)       AS orders,
    SUM(f.amount)  AS revenue
FROM  fact_sales   f
JOIN  dim_customer c ON c.customer_key = f.customer_key
JOIN  dim_time     t ON t.time_key     = f.time_key
GROUP BY c.city, t.day_of_week
ORDER BY c.city, revenue DESC;
