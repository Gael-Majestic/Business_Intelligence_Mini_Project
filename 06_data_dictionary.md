# DMS580S Mini Project 2026 — BI Metadata Layer
## Domain: Online Electronics Retail
---

## 1. Data Dictionary

### Table: `orders_dw`
*Source: MySQL OLTP via ETL | Grain: one row per order*

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| order_id | INT | No | Unique order identifier from MySQL. Primary key in this table. |
| customer_name | VARCHAR(100) | No | Full name of the customer who placed the order. Used as join key with `customer_activity`. |
| product | VARCHAR(100) | No | Name of the purchased product. Must exactly match product names in `customer_activity` for the JOIN to succeed. |
| category | VARCHAR(50) | Yes | Product category (Laptop, Smartphone, Audio, Monitor, Accessory). |
| brand | VARCHAR(50) | Yes | Product manufacturer brand (Apple, Dell, Samsung, etc.). |
| quantity | INT | No | Number of units purchased in this order. Always ≥ 1. |
| amount | NUMERIC(10,2) | No | Total sale value in USD (quantity × unit_price). |
| order_date | DATE | No | Date the order was placed. Format: YYYY-MM-DD. |
| status | VARCHAR(20) | Yes | Order status. All records in this dataset are 'Completed'. |
| city | VARCHAR(50) | Yes | Customer's city of residence. |
| country | VARCHAR(50) | Yes | Customer's country (DRC or South Africa). |

---

### Table: `customer_activity`
*Source: MongoDB OLTP via ETL | Grain: one row per user action*

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| session_id | VARCHAR(20) | Yes | Browser or app session identifier from MongoDB. Not unique across rows (multiple events per session). |
| customer_name | VARCHAR(100) | No | Full name of the customer who performed the activity. Join key with `orders_dw`. |
| product | VARCHAR(100) | No | Product the customer interacted with. Must exactly match product names in `orders_dw`. |
| activity | VARCHAR(20) | No | Type of interaction. Constrained to: `Viewed`, `Added to Cart`, `Purchased`. |
| device | VARCHAR(20) | Yes | Device type used for the session (Mobile, Desktop, Tablet). |
| timestamp | TIMESTAMP | No | Date and time of the activity event. Format: YYYY-MM-DD HH:MM:SS. Source: MongoDB ISODate, stripped of timezone offset during ETL. |

---

### Table: `customer_analytics`
*Integrated analytical table | Built from JOIN of orders_dw + customer_activity | Grain: one row per matched order–activity pair*

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| analytics_id | SERIAL | No | System-generated surrogate key. Unique per row in this table. |
| customer_name | VARCHAR(100) | No | Customer full name. Inherited from both source tables via equi-join. |
| product | VARCHAR(100) | No | Product name. The join key that links a purchase event to a browsing event. |
| activity | VARCHAR(20) | No | Behavioural activity type from `customer_activity`. |
| amount | NUMERIC(10,2) | Yes | Transaction amount from `orders_dw`. NULL if no matching order exists. |
| order_date | DATE | Yes | Date of the matching order from `orders_dw`. |
| activity_timestamp | TIMESTAMP | Yes | Timestamp of the activity from `customer_activity`. |

---

### Dimension Tables (Star Schema)

| Table | Grain | Key Field |
|-------|-------|-----------|
| `dim_customer` | One row per unique customer | customer_key |
| `dim_product` | One row per unique product SKU | product_key |
| `dim_time` | One row per calendar date | time_key |
| `dim_activity_type` | One row per activity type (3 rows total) | activity_key |

### Fact Table (Star Schema)

| Table | Grain | Measures |
|-------|-------|---------|
| `fact_sales` | One row per sale event | quantity, amount |

---

## 2. Business Rules

### BR-01: Amount Calculation
`amount = quantity × unit_price`
The ETL does not recalculate amount — it is inherited directly from the MySQL `orders` table where it was set at order creation. Any discrepancy between `amount` and `quantity × unit_price` from `dim_product` signals a discount or promotional price.

### BR-02: Join Integrity (customer_analytics)
The JOIN between `orders_dw` and `customer_activity` uses `customer_name` AND `product` as the composite key. Both fields must match exactly (case-sensitive). Records that exist only in one source table will not appear in `customer_analytics`. This is expected — not all browsing sessions result in a purchase, and not all purchases have recorded activity.

### BR-03: Activity Sequence Logic
For a given (customer_name, product) pair, the activity funnel is:
`Viewed` → `Added to Cart` → `Purchased`
A `Purchased` record without a prior `Viewed` or `Added to Cart` record in the same session is valid (represents direct purchase or activity data lag).

### BR-04: Currency
All `amount` and `unit_price` values are denominated in **USD**. No currency conversion is applied. Analysts should note this when comparing to local-currency KPIs.

### BR-05: ETL Idempotency
All three DW tables are truncated before each ETL run (`TRUNCATE TABLE`). The pipeline is safe to re-run; data is replaced, not duplicated.

### BR-06: Status Filter
Only orders with `status = 'Completed'` should be used in revenue aggregations. Returns and cancellations (if introduced in future data) will carry different status values and must be excluded from revenue metrics.

### BR-07: Timestamp Normalization
MongoDB `ISODate` objects are stored with UTC timezone. During ETL, the timezone offset is stripped and the value is stored as a naive `TIMESTAMP` in PostgreSQL. Analysts should treat all timestamps as UTC.

### BR-08: Country Segmentation
The dataset covers two countries: **DRC** (Kinshasa, Lubumbashi, Goma) and **South Africa** (Johannesburg, Cape Town, Durban, Pretoria). Country-level aggregations split on the `country` field in `orders_dw`.

### BR-09: Minimum Record Requirements
The pipeline enforces a minimum dataset size at load time:
- `orders_dw` must contain ≥ 30 rows
- `customer_activity` must contain ≥ 15 rows
Any run producing fewer rows should be investigated for extraction errors.

### BR-10: Metabase Refresh
Metabase dashboards read from `customer_analytics` and `orders_dw`. After each ETL run, trigger a manual sync in Metabase (Admin → Databases → Sync database schema) to reflect new data in visualizations.

---

## 3. Analytical KPIs Defined

| KPI | Formula | Source Table |
|-----|---------|-------------|
| Total Revenue | `SUM(amount)` | orders_dw |
| Average Order Value | `AVG(amount)` | orders_dw |
| Units Sold | `SUM(quantity)` | orders_dw |
| Conversion Rate | `COUNT(Purchased) / COUNT(Viewed) × 100` | customer_activity |
| Revenue by Category | `SUM(amount) GROUP BY category` | orders_dw |
| Monthly Growth | `SUM(amount) GROUP BY month` window function | orders_dw |
| Customer Lifetime Value | `SUM(amount) GROUP BY customer_name` | orders_dw |
