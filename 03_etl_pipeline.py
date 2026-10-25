#!/usr/bin/env python3
"""
DMS580S Mini Project 2026 — ETL Pipeline
Domain: Online Electronics Retail

Pipeline:
  1. EXTRACT   — MySQL   → orders_raw.csv, customers.csv, products.csv
                 MongoDB → activities_raw.csv
  2. TRANSFORM — clean, standardize, remove _id, check minimum row counts (BR-09)
  3. LOAD      — PostgreSQL COPY into orders_dw and customer_activity,
                 then build customer_analytics and the star schema
                 (dim_customer, dim_product, dim_time, dim_activity_type, fact_sales)

Requirements:
  pip install -r requirements.txt

The connection defaults match docker-compose.yml, so after `docker compose up -d --wait`
the pipeline runs with no settings at all:  python 03_etl_pipeline.py
"""

import csv
import os
import tempfile
from datetime import datetime
from pathlib import Path

import pandas as pd

# ── Connection settings ────────────────────────────────────────────────────────
# Defaults = docker-compose.yml. Override with environment variables when the
# databases run elsewhere (e.g. MYSQL_HOST=mysql inside the Compose network).
MYSQL_CFG = {
    "host": os.getenv("MYSQL_HOST", "127.0.0.1"),
    "port": int(os.getenv("MYSQL_PORT", "3309")),
    "user": os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", "rootpass"),
    "database": "electronics_retail",
}

MONGO_URI = os.getenv("MONGO_URI", "mongodb://127.0.0.1:27017/")
MONGO_DB = "electronics_retail_behavior"
MONGO_COLL = "customer_activity"

PG_CFG = {
    "host": os.getenv("PG_HOST", "127.0.0.1"),
    "port": int(os.getenv("PG_PORT", "5432")),
    "user": os.getenv("PG_USER", "admin"),
    "password": os.getenv("PG_PASSWORD", "adminpass"),
    "dbname": "electronics_dw",
}

# ── Intermediate files ─────────────────────────────────────────────────────────
# The system temp folder works on Linux, macOS and Windows (/tmp does not exist
# on Windows). Set ETL_WORK_DIR to keep the CSVs somewhere you can inspect them.
WORK_DIR = Path(os.getenv("ETL_WORK_DIR", Path(tempfile.gettempdir()) / "dms580s_etl"))
RAW_ORDERS_CSV = WORK_DIR / "orders_raw.csv"
RAW_ACTIVITIES_CSV = WORK_DIR / "activities_raw.csv"
CUSTOMERS_CSV = WORK_DIR / "customers.csv"
PRODUCTS_CSV = WORK_DIR / "products.csv"
CLEAN_ORDERS_CSV = WORK_DIR / "orders_clean.csv"
CLEAN_ACTIVITIES_CSV = WORK_DIR / "activities_clean.csv"

# ── Business rules (06_data_dictionary.md) ─────────────────────────────────────
VALID_ACTIVITIES = ("Viewed", "Added to Cart", "Purchased")
MIN_ORDERS = 30  # BR-09
MIN_ACTIVITIES = 15  # BR-09

ORDER_COLUMNS = [
    "order_id", "customer_name", "product", "category", "brand",
    "quantity", "amount", "order_date", "status", "city", "country",
]  # fmt: skip
ACTIVITY_COLUMNS = ["session_id", "customer_name", "product", "activity", "device", "timestamp"]


def write_csv(rows, path, fieldnames=None):
    """Write a list of dicts to CSV. An empty extract is an error, not an empty file."""
    if not rows:
        raise ValueError(f"No rows to write to {path}: is the source database seeded?")
    fieldnames = fieldnames or list(rows[0].keys())
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def standardize_columns(df):
    """Column names in snake_case: ' Order Date ' → 'order_date'."""
    df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]
    return df


# ══════════════════════════════════════════════════════════════════════════════
# STEP 1 — EXTRACT
# ══════════════════════════════════════════════════════════════════════════════


def extract_mysql():
    """Export the denormalized orders view, plus customers and products for the dimensions."""
    import mysql.connector

    print("[EXTRACT] Connecting to MySQL …")
    conn = mysql.connector.connect(**MYSQL_CFG)
    cursor = conn.cursor(dictionary=True)

    exports = [
        ("SELECT * FROM v_orders_export ORDER BY order_id;", RAW_ORDERS_CSV),
        ("SELECT customer_name, email, city, country FROM customers ORDER BY customer_id;", CUSTOMERS_CSV),
        ("SELECT product_name, category, brand, unit_price FROM products ORDER BY product_id;", PRODUCTS_CSV),
    ]
    for query, path in exports:
        cursor.execute(query)
        rows = cursor.fetchall()
        write_csv(rows, path)
        print(f"[EXTRACT] MySQL  → {len(rows)} rows written to {path}")

    cursor.close()
    conn.close()


def extract_mongodb():
    """Query MongoDB and write all fields (including _id) to activities_raw.csv."""
    import pymongo

    print("[EXTRACT] Connecting to MongoDB …")
    client = pymongo.MongoClient(MONGO_URI)
    docs = list(client[MONGO_DB][MONGO_COLL].find({}))
    client.close()

    # Collect the keys of ALL documents (MongoDB documents need not share a shape),
    # in the order they are first seen.
    all_keys = list(dict.fromkeys(key for doc in docs for key in doc))

    for doc in docs:
        # Convert ObjectId and datetime to strings for CSV
        doc["_id"] = str(doc["_id"])
        if isinstance(doc.get("timestamp"), datetime):
            doc["timestamp"] = doc["timestamp"].strftime("%Y-%m-%d %H:%M:%S")

    write_csv(docs, RAW_ACTIVITIES_CSV, fieldnames=all_keys)
    print(f"[EXTRACT] MongoDB → {len(docs)} docs written to {RAW_ACTIVITIES_CSV}")


# ══════════════════════════════════════════════════════════════════════════════
# STEP 2 — TRANSFORM
# Pure functions (DataFrame in, DataFrame out), so they can be tested without
# any database: see tests/test_transform.py.
# ══════════════════════════════════════════════════════════════════════════════


def transform_orders(df):
    """
    Clean the raw orders:
      - Standardize column names (snake_case)
      - Remove rows with nulls in critical fields
      - Ensure date format is YYYY-MM-DD
      - Cast amount to float (2 decimals), quantity to int
      - Keep the warehouse columns, in the warehouse order
    """
    df = standardize_columns(df.copy())

    # Remove rows with nulls in critical fields (before casting, which would fail on them)
    critical = ["customer_name", "product", "amount", "order_date"]
    before = len(df)
    df = df.dropna(subset=critical)
    dropped = before - len(df)
    if dropped:
        print(f"  [!] Dropped {dropped} rows with nulls in critical fields")

    # Enforce data types
    df["order_date"] = pd.to_datetime(df["order_date"]).dt.strftime("%Y-%m-%d")
    df["amount"] = df["amount"].astype(float).round(2)
    df["quantity"] = df["quantity"].astype(int)

    return df[ORDER_COLUMNS]


def transform_activities(df):
    """
    Clean the raw activities:
      - Drop MongoDB _id field
      - Standardize column names
      - Standardize timestamp to YYYY-MM-DD HH:MM:SS
      - Validate activity values (Viewed | Added to Cart | Purchased)
    """
    # Drop MongoDB internal _id — not needed in the warehouse
    df = df.drop(columns=["_id"], errors="ignore")
    df = standardize_columns(df)

    # Standardize timestamp
    df["timestamp"] = pd.to_datetime(df["timestamp"]).dt.strftime("%Y-%m-%d %H:%M:%S")

    # Validate activity values
    invalid_mask = ~df["activity"].isin(VALID_ACTIVITIES)
    if invalid_mask.any():
        print(f"  [!] Dropping {invalid_mask.sum()} rows with invalid activity values")
        df = df[~invalid_mask]

    return df[ACTIVITY_COLUMNS]


def check_minimum_rows(orders, activities):
    """BR-09: a run with fewer rows than this points to an extraction problem."""
    problems = []
    if len(orders) < MIN_ORDERS:
        problems.append(f"orders_dw would get {len(orders)} rows (minimum {MIN_ORDERS})")
    if len(activities) < MIN_ACTIVITIES:
        problems.append(f"customer_activity would get {len(activities)} rows (minimum {MIN_ACTIVITIES})")
    if problems:
        raise ValueError("BR-09 failed: " + "; ".join(problems))


def run_transform():
    print("[TRANSFORM] Cleaning orders …")
    orders = transform_orders(pd.read_csv(RAW_ORDERS_CSV))
    orders.to_csv(CLEAN_ORDERS_CSV, index=False)
    print(f"[TRANSFORM] Orders  → {len(orders)} clean rows → {CLEAN_ORDERS_CSV}")

    print("[TRANSFORM] Cleaning activities …")
    activities = transform_activities(pd.read_csv(RAW_ACTIVITIES_CSV))
    activities.to_csv(CLEAN_ACTIVITIES_CSV, index=False)
    print(f"[TRANSFORM] Activities → {len(activities)} clean rows → {CLEAN_ACTIVITIES_CSV}")

    check_minimum_rows(orders, activities)
    print(f"[TRANSFORM] BR-09 minimum row counts met ({MIN_ORDERS} orders, {MIN_ACTIVITIES} activities)")


# ══════════════════════════════════════════════════════════════════════════════
# STEP 3 — LOAD
# ══════════════════════════════════════════════════════════════════════════════

# The integrated table: every activity matched to the orders of the same customer
# and product (BR-02).
BUILD_CUSTOMER_ANALYTICS = """
    INSERT INTO customer_analytics
        (customer_name, product, activity, amount, order_date, activity_timestamp)
    SELECT o.customer_name, o.product, a.activity, o.amount, o.order_date, a.timestamp
    FROM   orders_dw         o
    JOIN   customer_activity a
      ON   o.customer_name = a.customer_name
     AND   o.product       = a.product;
"""

# The star schema: dimensions first, then the fact table that points to them.
BUILD_STAR_SCHEMA = [
    # One row per activity type (3 rows)
    """
    INSERT INTO dim_activity_type (activity_type)
    VALUES ('Viewed'), ('Added to Cart'), ('Purchased');
    """,
    # One row per calendar date on which an order was placed
    """
    INSERT INTO dim_time (full_date, day, month, month_name, quarter, year, day_of_week)
    SELECT DISTINCT
        order_date,
        EXTRACT(DAY     FROM order_date)::INT,
        EXTRACT(MONTH   FROM order_date)::INT,
        TO_CHAR(order_date, 'FMMonth'),
        EXTRACT(QUARTER FROM order_date)::INT,
        EXTRACT(YEAR    FROM order_date)::INT,
        TO_CHAR(order_date, 'FMDay')
    FROM orders_dw
    ORDER BY order_date;
    """,
    # One row per order (grain: one sale event), keyed to the four dimensions.
    # The natural keys (customer name, product name, date) find the surrogate keys.
    """
    INSERT INTO fact_sales (customer_key, product_key, time_key, activity_key, quantity, amount)
    SELECT c.customer_key, p.product_key, t.time_key, a.activity_key, o.quantity, o.amount
    FROM   orders_dw o
    JOIN   dim_customer      c ON c.customer_name = o.customer_name
    JOIN   dim_product       p ON p.product_name  = o.product
    JOIN   dim_time          t ON t.full_date     = o.order_date
    JOIN   dim_activity_type a ON a.activity_type = 'Purchased'
    ORDER BY o.order_id;
    """,
]


def copy_csv(cursor, table, columns, path):
    """Bulk-load a CSV with PostgreSQL's COPY (far faster than row-by-row INSERTs)."""
    with open(path, encoding="utf-8") as f:
        cursor.copy_expert(f"COPY {table} ({', '.join(columns)}) FROM STDIN WITH (FORMAT csv, HEADER true)", f)


def count(cursor, table):
    cursor.execute(f"SELECT COUNT(*) FROM {table};")
    return cursor.fetchone()[0]


def load_to_postgres():
    """
    Load the clean CSVs and build the derived tables, all in ONE transaction:
    if any step fails, nothing is committed and the warehouse keeps its previous data.
    Tables must already exist (created by 04_postgresql_dw.sql).
    """
    import psycopg2

    print("[LOAD] Connecting to PostgreSQL …")
    conn = psycopg2.connect(**PG_CFG)
    cursor = conn.cursor()

    # BR-05: idempotent runs. RESTART IDENTITY resets the SERIAL surrogate keys;
    # CASCADE is needed because fact_sales references the dimensions.
    cursor.execute("""
        TRUNCATE TABLE customer_analytics, orders_dw, customer_activity,
                       fact_sales, dim_customer, dim_product, dim_time, dim_activity_type
        RESTART IDENTITY CASCADE;
    """)

    print("[LOAD] Loading orders_dw and customer_activity …")
    copy_csv(cursor, "orders_dw", ORDER_COLUMNS, CLEAN_ORDERS_CSV)
    copy_csv(cursor, "customer_activity", ACTIVITY_COLUMNS, CLEAN_ACTIVITIES_CSV)

    print("[LOAD] Populating customer_analytics …")
    cursor.execute(BUILD_CUSTOMER_ANALYTICS)

    print("[LOAD] Building the star schema …")
    copy_csv(cursor, "dim_customer", ["customer_name", "email", "city", "country"], CUSTOMERS_CSV)
    copy_csv(cursor, "dim_product", ["product_name", "category", "brand", "unit_price"], PRODUCTS_CSV)
    for statement in BUILD_STAR_SCHEMA:
        cursor.execute(statement)

    # Every order must have found its customer, product and date; a missing match
    # would silently drop sales from every star-schema report.
    orders, facts = count(cursor, "orders_dw"), count(cursor, "fact_sales")
    if facts != orders:
        conn.rollback()
        raise ValueError(f"fact_sales has {facts} rows but orders_dw has {orders}: unmatched dimension keys")

    for table in (
        "orders_dw", "customer_activity", "customer_analytics",
        "dim_customer", "dim_product", "dim_time", "dim_activity_type", "fact_sales",
    ):  # fmt: skip
        print(f"  → {table}: {count(cursor, table)} rows")

    conn.commit()
    cursor.close()
    conn.close()
    print("[LOAD] All tables loaded successfully.")


# ══════════════════════════════════════════════════════════════════════════════
# ENTRY POINT
# ══════════════════════════════════════════════════════════════════════════════


def main():
    print("=" * 60)
    print("  DMS580S ETL Pipeline — Online Electronics Retail")
    print(f"  Run started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)

    WORK_DIR.mkdir(parents=True, exist_ok=True)

    # Extract
    extract_mysql()
    extract_mongodb()

    # Transform
    run_transform()

    # Load
    load_to_postgres()

    print("=" * 60)
    print("  ETL Pipeline completed successfully.")
    print("=" * 60)


if __name__ == "__main__":
    main()
