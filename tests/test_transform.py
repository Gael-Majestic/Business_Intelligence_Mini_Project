"""Unit tests for the transform step. No database needed: the transforms are pure functions."""

import importlib

import pandas as pd
import pytest

# The script's file name starts with a digit, so `import 03_etl_pipeline` is a syntax error;
# importlib loads it by name instead.
etl = importlib.import_module("03_etl_pipeline")


def raw_orders(**overrides):
    row = {
        "order_id": 1,
        "Customer Name": "Alice Dlamini",
        "product": "iPhone 15 Pro",
        "category": "Smartphone",
        "brand": "Apple",
        "quantity": "1",
        "amount": "999.989",
        "order_date": "2026-01-05 00:00:00",
        "status": "Completed",
        "city": "Johannesburg",
        "country": "South Africa",
        "unused_column": "dropped",
    }
    row.update(overrides)
    return pd.DataFrame([row])


def raw_activities(*activities):
    return pd.DataFrame(
        [
            {
                "_id": f"65f0c0ffee{n}",
                "session_id": "sess-001",
                "customer_name": "Alice Dlamini",
                "product": "iPhone 15 Pro",
                "activity": activity,
                "device": "Mobile",
                "timestamp": "2026-01-03T10:15:00Z",
            }
            for n, activity in enumerate(activities)
        ]
    )


class TestTransformOrders:
    def test_columns_are_snake_case_and_in_warehouse_order(self):
        assert list(etl.transform_orders(raw_orders()).columns) == etl.ORDER_COLUMNS

    def test_types_and_formats(self):
        row = etl.transform_orders(raw_orders()).iloc[0]
        assert row["order_date"] == "2026-01-05"
        assert row["amount"] == pytest.approx(999.99)
        assert row["quantity"] == 1

    def test_rows_missing_a_critical_field_are_dropped(self):
        df = pd.concat([raw_orders(), raw_orders(order_id=2, amount=None)])
        assert etl.transform_orders(df)["order_id"].tolist() == [1]

    def test_input_is_not_modified(self):
        df = raw_orders()
        etl.transform_orders(df)
        assert "Customer Name" in df.columns


class TestTransformActivities:
    def test_mongodb_id_is_removed_and_timestamp_normalised(self):
        df = etl.transform_activities(raw_activities("Viewed"))
        assert list(df.columns) == etl.ACTIVITY_COLUMNS
        assert df.iloc[0]["timestamp"] == "2026-01-03 10:15:00"

    def test_invalid_activity_values_are_dropped(self):
        df = etl.transform_activities(raw_activities("Viewed", "Wishlisted", "Purchased"))
        assert df["activity"].tolist() == ["Viewed", "Purchased"]


class TestMinimumRows:
    def test_enough_rows_pass(self):
        etl.check_minimum_rows(range(etl.MIN_ORDERS), range(etl.MIN_ACTIVITIES))

    def test_too_few_orders_stop_the_run(self):
        with pytest.raises(ValueError, match="BR-09.*orders_dw"):
            etl.check_minimum_rows(range(etl.MIN_ORDERS - 1), range(etl.MIN_ACTIVITIES))


def test_empty_extract_is_an_error(tmp_path):
    with pytest.raises(ValueError, match="seeded"):
        etl.write_csv([], tmp_path / "empty.csv")
