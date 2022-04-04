"""Interact with a Galaxy instance to upload files."""

import os
import argparse
from bioblend import galaxy

API_KEY = os.environ.get('BIOBLEND_API_KEY')


def main():
    """Make transaction."""
    if not API_KEY:
        raise ValueError('Environment variable BIOBLEND_API_KEY must be set')
    args = get_args()
    gi = galaxy.GalaxyInstance(url=args['url'], key=API_KEY)
    gi.tools.upload_file(args['file'], args['history_id'])
    print('Upload complete')


def get_args():
    """Collect CLI arguments."""
    p = argparse.ArgumentParser(description=(
        'Upload a local file to Galaxy with Bioblend.\n\nRequires an API key'
        ' for your Galaxy account to be set to the env variable'
        ' BIOBLEND_API_KEY.'
        ' This script should probably be run with nohup to prevent'
        ' interruptions from SSH dropout.\n\n'
        'Get your history ID using Bioblend:\n\n'
        'https://bioblend.readthedocs.io/en/latest/api_docs/galaxy/docs.html'
        '#view-histories-and-datasets'
    ))
    p.add_argument(
        '--history_id',
        dest='history_id',
        type=str,
        help='ID of Galaxy history to upload to',
    )
    p.add_argument(
        '--url',
        dest='url',
        type=str,
        help='ID of Galaxy history to upload to',
    )
    p.add_argument(
        '--file',
        dest='file',
        type=str,
        help='Path of file to upload',
    )
    return p.parse_args()


if __name__ == '__main__':
    main()
