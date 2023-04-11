"""Test sortable version function."""

from unittest import TestCase

from cluster_errors import sortable_version


class TestSortableVersion(TestCase):
    """Test sortable version function."""

    def test_it_can_be_used_to_sort_version_numbers(self):
        """Test that it can be used to sort versions correctly."""
        v1 = '0.0.1+galaxy1'
        v2 = '0.0.1+galaxy2'
        v3 = '0.1.0+galaxy2'
        v4 = '0.1.1+galaxy1'
        v5 = '0.10.0+galaxy1'
        self.assertTrue(sortable_version(v1) < sortable_version(v2))
        self.assertTrue(sortable_version(v2) < sortable_version(v3))
        self.assertTrue(sortable_version(v3) < sortable_version(v4))
        self.assertTrue(sortable_version(v3) < sortable_version(v5))
        self.assertTrue(sortable_version(v4) < sortable_version(v5))
