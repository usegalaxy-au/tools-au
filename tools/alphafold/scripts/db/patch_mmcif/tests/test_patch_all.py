import shutil
import unittest
from pathlib import Path
try:
    import patch_mmcif
except ImportError:
    print("Please run this script from the patch_mmcif.py directory.")
    exit(1)

MOCK_DB_PATH = Path('tests/mock-alphafold-db')
MOCK_MMCIF_DIR = MOCK_DB_PATH / 'pdb_mmcif/mmcif_files'
MMCIF_TEMP_DIR = Path('mmcif_patches')
EXISTING_CIF_FILE = MOCK_MMCIF_DIR / '3tc3.cif'

EXPECT_PATCHED = [
    '4ri6',
    '4ri7',
    '4gle',
]


class TestPatchAll(unittest.TestCase):
    def tearDown(self):
        for pdb_id in EXPECT_PATCHED:
            path = MOCK_MMCIF_DIR / f'{pdb_id}.cif'
            if path.exists():
                path.unlink()
        if MMCIF_TEMP_DIR.exists():
            shutil.rmtree(MMCIF_TEMP_DIR)
        return super().tearDown()

    def test_patch_one(self):
        patch_mmcif.patch_mmcif_file(EXPECT_PATCHED[0], MOCK_DB_PATH)
        path = MOCK_MMCIF_DIR / f'{EXPECT_PATCHED[0]}.cif'
        self.assertTrue(path.exists())

    def test_patch_all(self):
        patch_mmcif.patch_all(MOCK_DB_PATH)
        for pdb_id in EXPECT_PATCHED:
            path = MOCK_MMCIF_DIR / f'{pdb_id}.cif'
            self.assertTrue(path.exists())
        # Make sure existing file still present and unchanged
        self.assertTrue(EXISTING_CIF_FILE.exists())
        with open(EXISTING_CIF_FILE) as f:
            self.assertEqual(f.read().strip(' \n'), 'TEST_FILE')
