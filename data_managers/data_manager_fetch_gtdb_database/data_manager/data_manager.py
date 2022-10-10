"""Fetch GTDB database."""

import argparse
import json
import os
import shutil
import tarfile
import zipfile
from urllib.request import Request, urlopen

URLS = {
    'R202': (
        "https://data.gtdb.ecogenomic.org/releases"
        "/release202/202.0/auxillary_files/gtdbtk_r202_data.tar.gz"
    ),
    'R207': (
        "https://data.gtdb.ecogenomic.org/releases"
        "/release207/207.0/auxillary_files/gtdbtk_r207_data.tar.gz"
    ),
    'R207_v2': (
        "https://data.gtdb.ecogenomic.org/releases"
        "/release207/207.0/auxillary_files/gtdbtk_r207_v2_data.tar.gz"
    ),
}


def main():
    """Download and extract database."""
    args = get_args()
    wdir = os.path.abspath(os.path.join(os.getcwd(), 'db'))
    url_download(URLS[args.name], wdir)

    data_manager_schema = {
      "data_tables": {
        "gtdb": {
          "value": f"gtdb_{args.name.lower()}",
          "name": f"GTDB {args.name}",
          "path": ".",
        }
      }
    }

    with open(args.output) as f:
        params = json.load(f)
    target_dir = os.path.join(
        params['output_file'][0]['extra_files_path'],
        "db")
    os.makedirs(target_dir)
    shutil.move(wdir, target_dir)

    with open(args.output, 'w') as f:
        json.dump(data_manager_schema, f, sort_keys=True)


def get_args():
    """Return args object from CLI arguments."""
    parser = argparse.ArgumentParser(description='Create data manager json.')
    parser.add_argument(
        '--out',
        dest='output',
        action='store',
        help='JSON filename')
    parser.add_argument(
        '--name',
        dest='name',
        action='store',
        help='Data table entry unique ID')
    return parser.parse_args()


def url_download(url, workdir):
    file_path = os.path.join(workdir, 'download.dat')
    if not os.path.exists(workdir):
        os.makedirs(workdir)
    src = None
    dst = None
    try:
        req = Request(url)
        src = urlopen(req)
        with open(file_path, 'wb') as dst:
            while True:
                chunk = src.read(2**10)
                if chunk:
                    dst.write(chunk)
                else:
                    break
    finally:
        if src:
            src.close()
    if tarfile.is_tarfile(file_path):
        fh = tarfile.open(file_path, 'r:*')
    elif zipfile.is_zipfile(file_path):
        fh = zipfile.ZipFile(file_path, 'r')
    else:
        return
    fh.extractall(workdir)
    os.remove(file_path)


if __name__ == '__main__':
    main()
