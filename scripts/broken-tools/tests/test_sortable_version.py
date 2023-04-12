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
        v6 = '2.3.7'

        comparisons = [
            (v1, v2),
            (v2, v3),
            (v3, v4),
            (v3, v5),
            (v4, v5),
        ]

        for va, vb in comparisons:
            a = sortable_version(va)
            b = sortable_version(vb)
            self.assertTrue(a < b, f'{a} !< {b}')

        self.assertEqual(sortable_version(v6), ('002', '003', '007'))
