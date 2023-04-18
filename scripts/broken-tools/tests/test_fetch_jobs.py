"""Unit tests for fetch_jobs.py script."""

import pandas as pd
from datetime import datetime
from unittest import TestCase

from fetch_jobs import count_unique_users, flatten_rows


class TestFetchTools(TestCase):
    """Test fetch tools functions/classes."""

    def test_count_unique_users(self):
        df = pd.DataFrame([
            [123, 'ok'],
            [123, 'ok'],
            [234, 'ok'],
            [234, 'ok'],
            [234, 'error'],
            [234, 'error'],
            [234, 'error'],
            [345, 'ok'],
            [456, 'error'],
        ], columns=['user_id', 'state'])
        self.assertEqual(count_unique_users(df), 4)
        self.assertEqual(count_unique_users(df, state='error'), 2)

    def test_flatten_rows(self):
        """Test flatten rows function."""
        def parse_datetime(date_str: str) -> datetime.date:
            return datetime.fromisoformat(date_str)

        df = pd.DataFrame([
            [parse_datetime('2020-01-01'), 1, 'a'],  # init
            [parse_datetime('2020-01-01'), 1, 'a'],
            [parse_datetime('2020-01-01'), 1, 'a'],
            [parse_datetime('2020-01-01'), 1, 'a'],
            [parse_datetime('2020-01-01'), 1, 'b'],  # state
            [parse_datetime('2020-01-02'), 1, 'a'],  # date
            [parse_datetime('2020-01-02'), 1, 'a'],
            [parse_datetime('2020-01-02'), 1, 'a'],
            [parse_datetime('2020-01-02'), 2, 'a'],  # session
            [parse_datetime('2020-01-02'), 2, 'a'],
            [parse_datetime('2020-01-02'), 2, 'a'],
            [parse_datetime('2020-01-02'), 3, 'c'],  # session + state
        ], columns=['create_time', 'session_id', 'state'])
        df = flatten_rows(df)
        self.assertEqual(len(df), 5)
