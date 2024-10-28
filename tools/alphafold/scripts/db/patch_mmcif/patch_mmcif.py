import argparse
import requests
import shutil
from pathlib import Path

RCSB_BASE_URL = 'https://files.rcsb.org/download/'
LOG_DIR = Path('logs')


def parse_args():
    parser = argparse.ArgumentParser(
        description="Download and place MMCIF files into AlphaFold DB.")
    parser.add_argument("db_path", type=Path,
                        help="Path to your AlphaFold database root")
    parser.add_argument(
        "-i", "--id", type=str, required=False,
        help=("4-char PDB ID for a missing .cif file"
              "  (if excluded, will attempt to sniff the database"
              " and patch all missing files)"))
    parser.add_argument(
        "--log", action="store_true",
        help="Write patched PDB files/IDs to log files in current directory")
    args = parser.parse_args()

    if args.id and len(args.id) != 4:
        parser.error("MMCIF_ID must be exactly 4 characters long.")
    if not args.db_path.is_dir():
        parser.error(f"Error: DB_PATH '{args.db_path}' does not exist.")
    pdb_mmcif_path = args.db_path / "pdb_mmcif"
    if not pdb_mmcif_path.is_dir():
        parser.error(f"Error: database path '{pdb_mmcif_path}' does not exist."
                     " Are you sure that the provided DB_PATH is the root"
                     " folder of the AlphaFold reference database?")
    return args


def print_cli(*args, **kwargs):
    if __name__ == '__main__':
        print(*args, **kwargs)


def patch_mmcif_file(pdb_id: str, db_path: Path, log: bool = False):
    """Patch a single .cif file in the AlphaFold database."""
    db_mmcif_files_dir = db_path / "pdb_mmcif/mmcif_files"
    id_upper = pdb_id.upper()
    id_lower = pdb_id.lower()
    destination_path = db_mmcif_files_dir / f"{id_lower}.cif"
    cif_file = destination_path
    if log:
        mmcif_temp_dir = LOG_DIR / "mmcif_patches"
        mmcif_temp_dir.mkdir(exist_ok=True)
        cif_file = mmcif_temp_dir / f"{id_lower}.cif"

    url = f"{RCSB_BASE_URL}{id_upper}.cif"
    print_cli(f"Downloading file: {url}...")
    response = requests.get(url)
    if response.status_code == 200:
        cif_file.write_bytes(response.content)
    else:
        raise IOError(f"Error: Could not download file {id_upper}.cif")

    if log:
        shutil.copyfile(cif_file, destination_path)
    print_cli(f"Written {destination_path}")


def patch_all(db_path: Path, log: bool = False):
    """Calculate and patch all missing MMCIF files in the databases."""
    def write_ids_to_file(ids, filename):
        if log:
            print_cli(f"Writing logs/{filename}...")
            with open(LOG_DIR / filename, 'w') as f:
                f.write('\n'.join(ids))

    db_mmcif_files_dir = db_path / "pdb_mmcif/mmcif_files"
    pdb70_file = db_path / "pdb70/pdb70_clu.tsv"
    print_cli(f"Reading required MMCIF IDs from {pdb70_file}...")
    with open(pdb70_file) as f:
        required_mmcif_ids = {
            x.split()[0].split('_')[0].lower()  # from line "XXXX_B  YYYY_B"
            for x in f.readlines()
            if x.split()
        }
    print_cli(f"Found {len(required_mmcif_ids)} required MMCIF files.")
    write_ids_to_file(required_mmcif_ids, 'required_ids.txt')

    print_cli(f"Scanning {db_mmcif_files_dir} for existing MMCIF files...")
    existing_mmcif_ids = {
        filename.stem.lower()
        for filename in db_mmcif_files_dir.glob("*.cif")
    }
    print_cli(f"Found {len(existing_mmcif_ids)} existing MMCIF files.")
    write_ids_to_file(existing_mmcif_ids, 'existing_ids.txt')

    missing_mmcif_ids = required_mmcif_ids - existing_mmcif_ids
    print_cli(f'Found {len(missing_mmcif_ids)} missing MMCIF files.')
    write_ids_to_file(missing_mmcif_ids, 'missing_ids.txt')

    print_cli("Patching missing MMCIF files...")
    for mmcif_id in missing_mmcif_ids:
        patch_mmcif_file(mmcif_id, db_path, log=log)
    print_cli("Done.")


def main():
    args = parse_args()
    if args.id is None:
        print_cli("Attempting to patch all missing MMCIF files.")
        reply = input("Continue? [Y/n]\n> ")
        if reply.lower() != 'y':
            print_cli("Aborted.")
            return
        LOG_DIR.mkdir(exist_ok=True)
        patch_all(args.db_path, log=args.log)
    else:
        LOG_DIR.mkdir(exist_ok=True)
        print_cli(f"Attempting to patch MMCIF file {args.id}...")
        patch_mmcif_file(args.id, args.db_path, log=args.log)


if __name__ == '__main__':
    main()
