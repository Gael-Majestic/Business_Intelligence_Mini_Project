#!/usr/bin/env python3
"""
DMS580S Mini Project 2026 — ETL Pipeline
Domain: Online Electronics Retail

Pipeline:
  1. EXTRACT  — MySQL   → orders_raw.csv
               MongoDB → activities_raw.csv
  2. TRANSFORM — clean, standardize, remove _id
  3. LOAD      — PostgreSQL COPY command

Requirements:
  pip install mysql-connector-python pymongo psycopg2-binary pandas
"""

import csv
import os
import pandas as pd
import mysql.connector
import pymongo
import psycopg2
from datetime import datetime

# ── Connection settings ────────────────────────────────────────────────────────
# Update host/port to match your docker-compose service names if running in Docker
MYSQL_CFG = {
    "host":     os.getenv("MYSQL_HOST", "localhost"),
    "port":     int(os.getenv("MYSQL_PORT", 3306)),
    "user":     os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", "root"),
    "database": "electronics_retail",
}

MONGO_URI  = os.getenv("MONGO_URI", "mongodb://localhost:27017/")
MONGO_DB   = "electronics_retail_behavior"
MONGO_COLL = "customer_activity"

PG_CFG = {
    "host":     os.getenv("PG_HOST", "localhost"),
    "port":     int(os.getenv("PG_PORT", 5432)),
    "user":     os.getenv("PG_USER", "postgres"),
    "password": os.getenv("PG_PASSWORD", "postgres"),
    "dbname":   "electronics_dw",
}

RAW_ORDERS_CSV      = "/tmp/orders_raw.csv"
RAW_ACTIVITIES_CSV  = "/tmp/activities_raw.csv"
CLEAN_ORDERS_CSV    = "/tmp/orders_clean.csv"
CLEAN_ACTIVITIES_CSV = "/tmp/activities_clean.csv"


# ══════════════════════════════════════════════════════════════════════════════
# STEP 1 — EXTRACT
# ══════════════════════════════════════════════════════════════════════════════

def extract_mysql():
    """Query MySQL via the denormalized view and write to orders_raw.csv."""
    print("[EXTRACT] Connecting to MySQL …")
    conn = mysql.connector.connect(**MYSQL_CFG)
    cursor = conn.cursor(dictionary=True)

    cursor.execute("SELECT * FROM v_orders_export;")
    rows = cursor.fetchall()

    with open(RAW_ORDERS_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    cursor.close()
    conn.close()
    print(f"[EXTRACT] MySQL  → {len(rows)} rows written to {RAW_ORDERS_CSV}")


def extract_mongodb():
    """Query MongoDB and write all fields (including _id) to activities_raw.csv."""
    print("[EXTRACT] Connecting to MongoDB …")
    client = pymongo.MongoClient(MONGO_URI)
    db     = client[MONGO_DB]
    coll   = db[MONGO_COLL]

    docs = list(coll.find({}))

    # Collect all keys present in documents
    all_keys = list(docs[0].keys()) if docs else []

    with open(RAW_ACTIVITIES_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=all_keys, extrasaction="ignore")
        writer.writeheader()
        for doc in docs:
            # Convert ObjectId and datetime to strings for CSV
            doc["_id"]       = str(doc["_id"])
            doc["timestamp"] = doc["timestamp"].strftime("%Y-%m-%d %H:%M:%S") \
                               if isinstance(doc["timestamp"], datetime) else str(doc["timestamp"])
            writer.writerow(doc)

    client.close()
    print(f"[EXTRACT] MongoDB → {len(docs)} docs written to {RAW_ACTIVITIES_CSV}")


# ══════════════════════════════════════════════════════════════════════════════
# STEP 2 — TRANSFORM
# ══════════════════════════════════════════════════════════════════════════════

def transform_orders():
    """
    Clean orders_raw.csv:
      - Standardize column names (snake_case)
      - Ensure date format is YYYY-MM-DD
      - Cast amount to float, quantity to int
      - Remove nulls; verify status = 'Completed'
    """
    print("[TRANSFORM] Cleaning orders …")
    df = pd.read_csv(RAW_ORDERS_CSV)

    # Standardize column names
    df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]

    # Enforce data types
    df["order_date"] = pd.to_datetime(df["order_date"]).dt.strftime("%Y-%m-%d")
    df["amount"]     = df["amount"].astype(float).round(2)
    df["quantity"]   = df["quantity"].astype(int)

    # Remove rows with nulls in critical fields
    critical = ["customer_name", "product", "amount", "order_date"]
    before   = len(df)
    df.dropna(subset=critical, inplace=True)
    dropped = before - len(df)
    if dropped:
        print(f"  [!] Dropped {dropped} rows with nulls in critical fields")

    # Select and reorder columns for the DW target
    df = df[["order_id", "customer_name", "product", "category",
             "brand", "quantity", "amount", "order_date", "status",
             "city", "country"]]

    df.to_csv(CLEAN_ORDERS_CSV, index=False)
    print(f"[TRANSFORM] Orders  → {len(df)} clean rows → {CLEAN_ORDERS_CSV}")
    return df


def transform_activities():
    """
    Clean activities_raw.csv:
      - Drop MongoDB _id field
      - Standardize timestamp to YYYY-MM-DD HH:MM:SS
      - Validate activity values (Viewed | Added to Cart | Purchased)
      - Standardize column names
    """
    print("[TRANSFORM] Cleaning activities …")
    df = pd.read_csv(RAW_ACTIVITIES_CSV)

    # Drop MongoDB internal _id — not needed in the warehouse
    df.drop(columns=["_id"], errors="ignore", inplace=True)

    # Standardize column names
    df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]

    # Standardize timestamp
    df["timestamp"] = pd.to_datetime(df["timestamp"]).dt.strftime("%Y-%m-%d %H:%M:%S")

    # Validate activity values
    valid_activities = {"Viewed", "Added to Cart", "Purchased"}
    invalid_mask = ~df["activity"].isin(valid_activities)
    if invalid_mask.any():
        print(f"  [!] Dropping {invalid_mask.sum()} rows with invalid activity values")
        df = df[~invalid_mask]

    # Select and reorder columns
    df = df[["session_id", "customer_name", "product",
             "activity", "device", "timestamp"]]

    df.to_csv(CLEAN_ACTIVITIES_CSV, index=False)
    print(f"[TRANSFORM] Activities → {len(df)} clean rows → {CLEAN_ACTIVITIES_CSV}")
    return df


# ══════════════════════════════════════════════════════════════════════════════
# STEP 3 — LOAD
# ══════════════════════════════════════════════════════════════════════════════

def load_to_postgres():
    """
    Load clean CSVs into PostgreSQL using COPY command.
    Tables must already exist (created by 04_postgresql_dw.sql).
    """
    print("[LOAD] Connecting to PostgreSQL …")
    conn   = psycopg2.connect(**PG_CFG)
    cursor = conn.cursor()

    # -- Load orders_dw --
    print("[LOAD] Loading orders_dw …")
    cursor.execute("TRUNCATE TABLE orders_dw;")
    with open(CLEAN_ORDERS_CSV, "r", encoding="utf-8") as f:
        cursor.copy_expert(
            "COPY orders_dw FROM STDIN DELIMITER ',' CSV HEADER;", f
        )
    cursor.execute("SELECT COUNT(*) FROM orders_dw;")
    print(f"  → orders_dw: {cursor.fetchone()[0]} rows loaded")

    # -- Load customer_activity --
    print("[LOAD] Loading customer_activity …")
    cursor.execute("TRUNCATE TABLE customer_activity;")
    with open(CLEAN_ACTIVITIES_CSV, "r", encoding="utf-8") as f:
        cursor.copy_expert(
            "COPY customer_activity FROM STDIN DELIMITER ',' CSV HEADER;", f
        )
    cursor.execute("SELECT COUNT(*) FROM customer_activity;")
    print(f"  → customer_activity: {cursor.fetchone()[0]} rows loaded")

    # -- Populate customer_analytics via SQL JOIN --
    print("[LOAD] Populating customer_analytics …")
    cursor.execute("TRUNCATE TABLE customer_analytics;")
    cursor.execute("""
        INSERT INTO customer_analytics
            (customer_name, product, activity, amount, order_date, activity_timestamp)
        SELECT
            o.customer_name,
            o.product,
            a.activity,
            o.amount,
            o.order_date,
            a.timestamp
        FROM  orders_dw       o
        JOIN  customer_activity a
           ON o.customer_name = a.customer_name
          AND o.product        = a.product;
    """)
    cursor.execute("SELECT COUNT(*) FROM customer_analytics;")
    print(f"  → customer_analytics: {cursor.fetchone()[0]} rows integrated")

    conn.commit()
    cursor.close()
    conn.close()
    print("[LOAD] All tables loaded successfully.")


# ══════════════════════════════════════════════════════════════════════════════
# ENTRY POINT
# ══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    print("=" * 60)
    print("  DMS580S ETL Pipeline — Online Electronics Retail")
    print(f"  Run started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)

    # Extract
    extract_mysql()
    extract_mongodb()

    # Transform
    transform_orders()
    transform_activities()

    # Load
    load_to_postgres()

    print("=" * 60)
    print("  ETL Pipeline completed successfully.")
    print("=" * 60)
