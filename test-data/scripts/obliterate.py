#!/usr/bin/env python3

# AUTHOR: Cameron Hyde <c.hyde@qcif.edu.au>

"""Randomly obliterate a FASTA assembly to make it less contiguous.

Why on earth would you do that?

Some tools are trying to patch together and back-fill gappy assemblies. It's
easy to find shiny, contiguous genomes in the public domain, but not so easy to
find gappy, crappy ones. This tool allows you to make them :)

Requires the fasta library
(pip install git+https://github.com/neoformit/fasta.git)


Example usage:
-------------

# Lots of contigs with smallish gaps
./obliterate.py --n50 5000 --min-gap 200 --max-gap 3000 genome.fasta

# Fewer contigs but with larger gaps
./obliterate.py --n50 20000 --min-gap 2000 --max-gap 15000 genome.fasta

"""

try:
    import fasta
except ModuleNotFoundError:
    raise ModuleNotFoundError(
        "No module named 'fasta'\n\n"
        "This module can be installed directly from Github using pip:\n"
        "$ pip install git+https://github.com/neoformit/fasta.git\n")

import argparse
import random

# Defaults
MIN_GAP = 500
MAX_GAP = 15000
N50 = 50000


def obliterate(args):
    """Break up the sequence(s)."""
    obliterated = {}
    n50_stdev = args.n50 / 5

    fas = fasta.read(args.filename)
    for name, seq in fas.items():
        obliterated[name] = ''
        ngaps = round(len(seq) / args.n50)
        stop = 0
        for i in range(ngaps):
            start = stop + random.randint(args.min_gap, args.max_gap)
            stop = start + int(
                random.normalvariate(args.n50, n50_stdev))
            obliterated[f"{name}_frag_{i}"] = seq[start:stop]

    return obliterated


def get_args():
    """Parse args from CLI input."""
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument(
        'filename',
        type=str,
        help='Path to FASTA-formatted sequences to be processed')
    parser.add_argument(
        '--min-gap',
        dest='min_gap',
        type=int,
        default=MIN_GAP,
        help=f'Minimum gap size to create (default {MIN_GAP})')
    parser.add_argument(
        '--max-gap',
        dest='max_gap',
        type=int,
        default=MAX_GAP,
        help=f'Maximum gap size to create (default {MAX_GAP})')
    parser.add_argument(
        '--n50',
        dest='n50',
        type=int,
        default=N50,
        help=f'Desired N50 of output contigs (default {N50})')
    args = parser.parse_args()

    return args


def main():
    """Do the thing."""
    args = get_args()
    print(f"Obliterating {args.filename}...")

    fas = obliterate(args)
    outfile = f"{args.filename.rsplit('.', 1)[0]}.frags.fasta"
    fasta.write(fas, outfile)
    print(f"Obliteration complete - saved to {outfile}")


if __name__ == '__main__':
    main()
