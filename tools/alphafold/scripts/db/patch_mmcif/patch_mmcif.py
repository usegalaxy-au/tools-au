import argparse
import shutil
from pathlib import Path

import requests

RCSB_BASE_URL = 'https://files.rcsb.org/download/'
LOG_DIR = Path('logs')
LOCAL_MMCIF_DIR = Path('mmcif_files')
MMCIF_LOG_DIR = LOG_DIR / "mmcif_patches"
DB_PATH_MMCIF_FILES = "pdb_mmcif/mmcif_files"
DB_PATH_PDB70_CLU = "pdb70/pdb70_clu.tsv"
LOG_FILE_REQUIRED = "required_ids.log"
LOG_FILE_EXISTING = "existing_ids.log"
LOG_FILE_MISSING = "missing_ids.log"


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Patch missing MMCIF files in your AlphaFold DB. This script will"
            " sniff your databases for missing .cif files and download them"
            " from the RCSB PDB. If the --write-db flag is set, the files will"
            " be copied directly to the AlphaFold database mmcif_files"
            " directory.\n\nExample usage:"
            "\n\n"
            "  # Write mmcif files locally (don't write to AF databases)\n"
            "  python patch_mmcif.py /my/alphafold/db/\n\n"
            "  # Patch all missing files in the database and log changes\n"
            "  python patch_mmcif.py /my/alphafold/db/ --write-db --log\n\n"
            "  # Patch a single missing file\n"
            "  python patch_mmcif.py /my/alphafold/db/ -i 4ri6 --write-db\n\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("db_path", type=Path,
                        help="Path to your AlphaFold database root")
    parser.add_argument(
        "-i", "--id", type=str, required=False,
        help=("4-char PDB ID for a .cif file to patch (non-case-sensitive)"
              " (if excluded, will attempt to sniff the database"
              " and patch all missing files)"))
    parser.add_argument(
        "--write-db", action="store_true", help=(
            'Copy the files directly to the AlphaFold database mmcif_files'
            ' directory. If this option is omitted, files will be written'
            ' locally to ./mmcif_files/*.cif and must then be manually copied'
            ' to the database pdb_mmcif/mmcif_files directory. Omit this'
            ' option to prevent the script from writing to your database.'
        )
    )
    parser.add_argument(
        "--log", action="store_true", help=(
            f"Write patched PDB files/IDs to ./{LOG_DIR}/."
            " This is useful for keeping track of which files were patched."
            f" The following files will be written: [{LOG_FILE_REQUIRED},"
            f" {LOG_FILE_EXISTING}, {LOG_FILE_MISSING}]. Patched MMCIF files"
            f" will be copied to ./{MMCIF_LOG_DIR}/."
        ),
    )
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


def patch_mmcif_file(
    pdb_id: str,
    db_path: Path,
    log: bool = False,
    write_db: bool = False,
):
    """Patch a single .cif file in the AlphaFold database."""
    if log:
        LOG_DIR.mkdir(exist_ok=True)
    if not write_db:
        LOCAL_MMCIF_DIR.mkdir(exist_ok=True)
    db_mmcif_files_dir = db_path / DB_PATH_MMCIF_FILES
    id_upper = pdb_id.upper()
    id_lower = pdb_id.lower()
    destination_path = (
        db_mmcif_files_dir / f"{id_lower}.cif"
        if write_db
        else LOCAL_MMCIF_DIR / f"{id_lower}.cif")
    url = f"{RCSB_BASE_URL}{id_upper}.cif"
    print_cli(f"Downloading file: {url}...")
    response = requests.get(url)
    if response.status_code == 200:
        destination_path.write_bytes(response.content)
    else:
        raise IOError(f"Error: Could not download file {id_upper}.cif")
    if log:
        MMCIF_LOG_DIR.mkdir(exist_ok=True)
        log_cif_file = MMCIF_LOG_DIR / f"{id_lower}.cif"
        shutil.copyfile(destination_path, log_cif_file)
    print_cli(f"Written {destination_path}")


def patch_all(
    db_path: Path,
    log: bool = False,
    prompt: bool = False,
    write_db: bool = False
):
    """Calculate and patch all missing MMCIF files in the databases."""
    def write_ids_to_file(ids, filename):
        if log:
            print_cli(f"Writing logs/{filename}...")
            with open(LOG_DIR / filename, 'w') as f:
                f.write('\n'.join(ids))

    if log:
        LOG_DIR.mkdir(exist_ok=True)
    db_mmcif_files_dir = db_path / DB_PATH_MMCIF_FILES
    pdb70_file = db_path / DB_PATH_PDB70_CLU
    print_cli(f"Reading required MMCIF IDs from {pdb70_file}...")
    mmcif_list = []
    with open(pdb70_file) as f:
        for line in f.readlines():
            x, y = line.split()  # from line "XXXX_B  YYYY_B"
            x = x.split('_')[0].lower()
            y = y.split('_')[0].lower()
            mmcif_list += [x, y]
    required_mmcif_ids = set(mmcif_list)
    print_cli(f"Found {len(required_mmcif_ids)} required MMCIF files.")
    write_ids_to_file(required_mmcif_ids, LOG_FILE_REQUIRED)

    print_cli(f"Scanning {db_mmcif_files_dir} for existing MMCIF files...")
    existing_mmcif_ids = {
        filename.stem.lower()
        for filename in db_mmcif_files_dir.glob("*.cif")
    }
    print_cli(f"Found {len(existing_mmcif_ids)} existing MMCIF files.")
    write_ids_to_file(existing_mmcif_ids, LOG_FILE_EXISTING)

    missing_mmcif_ids = required_mmcif_ids - existing_mmcif_ids
    print_cli(f'Found {len(missing_mmcif_ids)} missing MMCIF files.')
    write_ids_to_file(missing_mmcif_ids, LOG_FILE_MISSING)

    if not len(missing_mmcif_ids):
        print_cli("No missing MMCIF files found. Exiting...")
        return

    if prompt:
        reply = input("\nPatch missing files? [Y/n]\n> ")
        if reply.lower() != 'y':
            print_cli("Aborted.")
            return

    print_cli("Patching missing MMCIF files...")
    for mmcif_id in missing_mmcif_ids:
        patch_mmcif_file(mmcif_id, db_path, log=log, write_db=write_db)
    print_cli("Done.")


def main():
    args = parse_args()

    if not args.write_db:
        if LOCAL_MMCIF_DIR.exists():
            reply = input(
                f"Local directory ./{LOCAL_MMCIF_DIR} already exists."
                " Any *.cif patches that are downloaded will overwrite files"
                " in this directory with the same name.\n"
                " Continue? [y/N]\n> ")
            if reply.lower() != 'y':
                print_cli("Aborted.")
                return

    if args.id is None:
        print_cli("Attempting to patch all missing MMCIF files in"
                  f" {args.db_path}...")
        patch_all(
            args.db_path,
            log=args.log,
            write_db=args.write_db,
            prompt=True,
        )
    else:
        print_cli(f"Attempting to patch MMCIF file {args.id}...")
        patch_mmcif_file(
            args.id,
            args.db_path,
            log=args.log,
            write_db=args.write_db,
        )


if __name__ == '__main__':
    main()
