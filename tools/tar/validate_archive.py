"""Validate the extracted archive.

It should contain either:

- files
- a directory of files

Otherwise raise error.
"""

import os
import argparse


class InvalidArchiveException(ValueError):
    """The archive provided is not an accepted structure."""

    pass


def main():
    """Move files to the root folder if they aren't there already."""
    args = get_args()
    wdir = os.getcwd()
    archive_root = os.path.join(wdir, args.path)
    for root, dirs, files in os.walk(args.path):
        validate(dirs, files)
        if files and root != archive_root:
            for f in files:
                path = os.path.join(root, f)
                os.rename(path, os.path.join(archive_root, f))
            break


def get_args():
    """Parse and return arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        'path',
        help="extracted archive directory",
        default='.',
        type=str,
    )
    args = parser.parse_args()
    if not os.path.exists(args.path):
        raise FileNotFoundError(f'The path does not exist: {args.path}')

    return args


def validate(dirs, files):
    """Validate the archive structure.

    Assert that directory contains either files or a single dir.
    """
    if (dirs and files) or len(dirs) > 1:
        files_str = '\n'.join(files)
        dirs_str = '\n'.join(dirs)
        raise InvalidArchiveException(
            "The archive provided was not in an accepted file structure."
            " The archive must contain either files, or a directory of"
            " files.\n\n"
            f"Files:\n{files_str}\n\n"
            f"Directories:\n{dirs_str}\n"
        )


if __name__ == '__main__':
    main()
