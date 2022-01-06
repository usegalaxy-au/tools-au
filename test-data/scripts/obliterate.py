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

# Lots of small contigs with little gaps
./obliterate.py --n50 5000 --min-gap 200 --max-gap 3000 genome.fasta

# Longer contigs with some gaps
./obliterate.py --n50 200000 --min-gap 1000 --max-gap 15000 genome.fasta

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
import statistics

# Defaults
MIN_GAP = 500
MAX_GAP = 15000
N50 = 50000


def obliterate(args):
    """Break up the sequence(s)."""
    gaps = []
    obliterated = {}

    fas = fasta.read(args.filename)
    for name, seq in fas.items():
        i = 0
        slen = len(seq)
        if slen < args.n50:
            print(f"Sequence {name} smaller than N50 ({args.n50})")
            trunc_limit = slen / 4
            start = random.randint(0, trunc_limit)
            stop = slen - random.randint(1, trunc_limit)
            frag = seq[start:stop]
            if len(frag) > args.n50 / 10:
                obliterated[f"{name}_frag_{i}"] = frag
        else:
            stop = 0
            n50_stdev = args.n50 / 5
            while True:
                gap = random.randint(args.min_gap, args.max_gap)
                gaps.append(gap)
                start = stop + gap
                stop = min(
                    start + int(random.normalvariate(args.n50, n50_stdev)),
                    slen)
                if start > slen:
                    break
                frag = seq[start:stop]
                if len(frag) > args.n50 / 10:
                    obliterated[f"{name}_frag_{i}"] = seq[start:stop]
                    i += 1
                else:
                    print(
                        "Skipping fragment smaller than N50/10",
                        f" ({args.n50/10})")

    return obliterated, gaps


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

    fas, gaps = obliterate(args)
    outfile = f"{args.filename.rsplit('.', 1)[0]}.frags.fasta"
    fasta.write(fas, outfile)
    fas_lengths = [len(x) for x in fas.values()]
    mean_bp = round(statistics.mean(fas_lengths))
    mean_gap = round(statistics.mean(gaps))
    print(f"Obliteration complete - saved to {outfile}")
    print(f"  - contigs:     {len(fas)}")
    print(f"  - min length:  {min(fas_lengths)} bp")
    print(f"  - max length:  {max(fas_lengths)} bp")
    print(f"  - mean length: {mean_bp} bp")
    print(f"  - mean gap:    {mean_gap} bp")


if __name__ == '__main__':
    main()
