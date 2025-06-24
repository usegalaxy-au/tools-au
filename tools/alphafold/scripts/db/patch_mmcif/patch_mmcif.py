import argparse
import requests
import shutil
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

RCSB_BASE_URL = 'https://files.rcsb.org/download/'
LOG_DIR = Path('logs')
LOCAL_MMCIF_DIR = Path('pdb_mmcif/mmcif_files')
MMCIF_LOG_DIR = LOG_DIR / "mmcif_patches"
DB_PATH_MMCIF_FILES = "pdb_mmcif/mmcif_files"
DB_PATH_PDB_SEQRES = "pdb_seqres/pdb_seqres.txt"
DB_PATH_OBSOLETE =  "pdb_mmcif/obsolete.dat"
DB_PATH_PDB70_CLU = "pdb70/pdb70_clu.tsv"
DB_PATH_PDB100 = "pdb100/pdb100_2021Mar03_pdb.ffindex"
LOG_FILE_REQUIRED = "required_ids.log"
LOG_FILE_EXISTING = "existing_ids.log"
LOG_FILE_MISSING = "missing_ids.log"
LOG_FILE_EXTRA = "extra_ids.log"


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
            f" {LOG_FILE_EXISTING}, {LOG_FILE_MISSING}, {LOG_FILE_EXTRA}]. Patched MMCIF files"
            f" will be copied to ./{MMCIF_LOG_DIR}/."
        ),
    )
    parser.add_argument(
        "--threads", type=int, default=8, help=(
            "Number of concurrent downloads to use (default: 8)."
        )
    )
    parser.add_argument(
        "--prune", action="store_true", help=(
            "Move orphaned (unreferenced) MMCIF files to ./orphaned/"
            " so they can be reviewed or cleaned up manually."
        )
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
    write_db: bool = False,
    threads: int = 8,
    prune: bool = False,
):
    """Calculate and patch all missing MMCIF files in the databases."""
    def write_ids_to_file(ids, filename):
        if log:
            print_cli(f"Writing logs/{filename}...")
            with open(LOG_DIR / filename, 'w') as f:
                f.write('\n'.join(sorted(ids)))

    if log:
        LOG_DIR.mkdir(exist_ok=True)
    db_mmcif_files_dir = db_path / DB_PATH_MMCIF_FILES
    pdb70_file = db_path / DB_PATH_PDB70_CLU
    required_mmcif_ids = set()
    if pdb70_file.exists():
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
    else:
        print_cli(f"Warning: {pdb70_file} not found, skipping extra IDs.")

    pdb100_file = db_path / DB_PATH_PDB100
    if pdb100_file.exists():
        print_cli(f"Reading required MMCIF IDs from {pdb100_file}...")
        with open(pdb100_file) as f:
            for line in f.readlines():
                pdb_chain = line.split()[0]  # e.g. 1a7e_A
                pdb_id = pdb_chain.split('_')[0].lower()
                if len(pdb_id) == 4:
                    required_mmcif_ids.add(pdb_id)
        print_cli(f"Updated to {len(required_mmcif_ids)} required MMCIF files.")
    else:
        print_cli(f"Warning: {pdb100_file} not found, skipping extra IDs.")

    pdb_seqres_file = db_path / DB_PATH_PDB_SEQRES
    if pdb_seqres_file.exists():
        print_cli(f"Reading additional PDB IDs from {pdb_seqres_file}...")
        with open(pdb_seqres_file) as f:
            for line in f:
                if line.startswith(">"):
                    pdb_id = line[1:5].lower()  # Extract first 4 chars after '>'
                    required_mmcif_ids.add(pdb_id)
        print_cli(f"Updated to {len(required_mmcif_ids)} total required MMCIF files.")
    else:
        print_cli(f"Warning: {pdb_seqres_file} not found, skipping extra IDs.")

    # Read obsolete IDs from obsolete.dat and remove from required_mmcif_ids
    obsolete_file = db_path / DB_PATH_OBSOLETE
    obsolete_ids = set()
    if obsolete_file.exists():
        print_cli(f"Reading obsolete IDs from {obsolete_file}...")
        with open(obsolete_file) as f:
            for line in f:
                if line.startswith("OBSLTE"):
                    parts = line.split()
                    if len(parts) >= 3:
                        obsolete_id = parts[2].lower()
                        if len(obsolete_id) == 4:
                            obsolete_ids.add(obsolete_id)
        print_cli(f"Found {len(obsolete_ids)} obsolete IDs.")
        required_mmcif_ids -= obsolete_ids
        print_cli(f"{len(required_mmcif_ids)} required MMCIF files after removing obsolete IDs.")
    else:
        print_cli(f"Warning: {obsolete_file} not found, skipping obsolete filtering.")
    write_ids_to_file(required_mmcif_ids, LOG_FILE_REQUIRED)

    print_cli(f"Scanning {db_mmcif_files_dir} for existing MMCIF files...")
    existing_mmcif_ids = {
        filename.stem.lower()
        for filename in db_mmcif_files_dir.glob("*.cif")
    }
    print_cli(f"Found {len(existing_mmcif_ids)} existing MMCIF files.")
    write_ids_to_file(existing_mmcif_ids, LOG_FILE_EXISTING)

    missing_mmcif_ids = required_mmcif_ids - existing_mmcif_ids
    extra_mmcif_ids = existing_mmcif_ids - required_mmcif_ids
    print_cli(f'Found {len(missing_mmcif_ids)} missing MMCIF files.')
    print_cli(f'Found {len(extra_mmcif_ids)} extra MMCIF files.')
    write_ids_to_file(missing_mmcif_ids, LOG_FILE_MISSING)
    write_ids_to_file(extra_mmcif_ids, LOG_FILE_EXTRA)

    if prune and extra_mmcif_ids:
        orphan_dir = db_mmcif_files_dir.parent / "orphaned"
        orphan_dir.mkdir(exist_ok=True)
        for eid in extra_mmcif_ids:
            old_path = db_mmcif_files_dir / f"{eid}.cif"
            new_path = orphan_dir / f"{eid}.cif"
            old_path.rename(new_path)
            print_cli(f"Moved unreferenced {eid}.cif to orphaned/")

    if not len(missing_mmcif_ids):
        print_cli("No missing MMCIF files found. Exiting...")
        return

    if prompt:
        reply = input("\nPatch missing files? [Y/n]\n> ")
        if reply.lower() != 'y':
            print_cli("Aborted.")
            return

    print_cli(f"Patching {len(missing_mmcif_ids)} missing MMCIF files using {threads} threads...")

    def download_wrapper(mmcif_id):
        try:
            patch_mmcif_file(mmcif_id, db_path, log=log, write_db=write_db)
            return (mmcif_id, True, None)
        except Exception as e:
            return (mmcif_id, False, str(e))

    with ThreadPoolExecutor(max_workers=threads) as executor:
        futures = {executor.submit(download_wrapper, mmcif_id): mmcif_id for mmcif_id in missing_mmcif_ids}
        completed = 0
        for future in as_completed(futures):
            mmcif_id, success, err = future.result()
            completed += 1
            if success:
                print_cli(f"[{completed}/{len(missing_mmcif_ids)}] Patched {mmcif_id}")
            else:
                print_cli(f"[{completed}/{len(missing_mmcif_ids)}] Failed {mmcif_id}: {err}")

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
            threads=args.threads,
            prune=args.prune,
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

