# Business intelligence pipeline: online electronics retail

Coursework for the DMS580S module (CPUT, 2026). The operational data of an online electronics retailer is
held in two sources, MySQL for orders and MongoDB for customer activity. A Python ETL script extracts it,
cleans it and loads it into a PostgreSQL warehouse built as a star schema, which Metabase then queries for
dashboards.

## Files

| File | Contents |
|---|---|
| `01_mysql_oltp.sql` | MySQL source database `electronics_retail`: schema and sample orders |
| `02_mongodb_seed.js` | MongoDB source `electronics_retail_behavior`: customer activity |
| `03_etl_pipeline.py` | ETL in Python (pandas): extract from MySQL and MongoDB, clean, load into PostgreSQL |
| `04_postgresql_dw.sql` | warehouse `electronics_dw`: star schema and example business queries |
| `05_star_schema.html` | diagram of the star schema |
| `06_data_dictionary.md` | data dictionary and metadata of the warehouse |
| `docker-compose.yml` | two MySQL nodes, MongoDB, PostgreSQL, Metabase, and a small Hadoop cluster that the ETL does not use |

## Running it

The passwords in `docker-compose.yml` are local demonstration values.

```bash
docker compose up -d

# sources
docker exec -i mysql-node-71 mysql -uroot -prootpass < 01_mysql_oltp.sql
docker exec -i mongodb mongosh < 02_mongodb_seed.js

# warehouse
docker exec -i postgres-dw psql -U admin -d warehouse -c "CREATE DATABASE electronics_dw;"
docker exec -i postgres-dw psql -U admin -d electronics_dw < 04_postgresql_dw.sql

# ETL (its defaults differ from the Compose settings, hence the variables)
pip install mysql-connector-python pymongo psycopg2-binary pandas
MYSQL_PORT=3309 MYSQL_PASSWORD=rootpass PG_USER=admin PG_PASSWORD=adminpass python 03_etl_pipeline.py
```

Metabase runs at http://localhost:3000. Connect it to PostgreSQL with host `postgres`, database
`electronics_dw` and user `admin`.
