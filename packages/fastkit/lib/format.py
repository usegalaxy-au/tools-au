#!/usr/bin/env python3

"""Reformat FASTA files in preparation for tool execution.

Available filters:
- Strip spaces from headers

"""

import sys
import argparse
from Bio import SeqIO


def main():
    """Reformat file as specified.

    This is structured so that additional filters can easily be added in
    future. Files are processed on a per-sequence basis.

    To create a new filter, add a "parser.add_argument" line, an entry to
    FUNC_MAP and a function to handle the filtering.
    """
    args = parse_args()
    with open(args.filename) as f:
        fas = list(SeqIO.parse(f, 'fasta'))

    available_filters = {
        k: v
        for k, v in args.__dict__.items()
        if k != 'filename'
    }
    filters = {
        k: v
        for k, v in available_filters.items()
        if v
    }
    if not filters:
        raise ValueError(
            "No filter specified on input file."
            + " You must specify an available filter:\n"
            + '\n'.join([
                f"  --{k.replace('_', '-')}"
                for k in available_filters.keys()
            ]))

    for seq in fas:
        for k, v in filters.items():
            sys.stdout.write(FUNC_MAP[k](seq))


def parse_args():
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument(
        "filename",
        type=str,
        help="A filename to parse and correct.",
    )
    parser.add_argument(
        '--strip-header-space',
        action='store_true',
        help="Strip spaces from title and replace with underscore",
    )
    return parser.parse_args()


def strip_header_space(seq):
    """Replace header spaces with underscores."""
    header, sequence = seq.format('fasta').split('\n', 1)
    return f"{header.replace(' ', '_')}\n{sequence}"


FUNC_MAP = {
    'strip_header_space': strip_header_space,
}


if __name__ == '__main__':
    main()
