#!/usr/bin/env python3

# AUTHOR: Cameron Hyde <c.hyde@qcif.edu.au>

"""Randomly mutate a FASTA file of sequences.

Why on earth would you do that?

Sometimes you might want a set of sequences that don't have 100% similarity.
These can be a pain in the ass to find, so it's easier to just make them :)

Requires the fasta library
(pip install git+https://github.com/neoformit/fasta.git)


Example usage:
-------------

# Mutate a set of fasta sequences to acheive 99% identity
./mutate.py -i 0.99 sequences.fasta > mutant.fasta

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
IDENTITY = 0.99

NUCL = ('a', 't', 'g', 'c', 'n')


def mutate(args):
    """Mutate the sequence(s)."""
    mutated = {}

    fas = fasta.read(args.filename)
    for name, seq in fas.items():
        slen = len(seq)
        n = int(slen * args.identity)
        indexes = {}

        # Collect residue indexes to replace
        while len(indexes) < n:
            ix = random.randint(0, slen)
            indexes = indexes | {ix}

        # Replace them
        for ix in indexes:
            # Choose a different residue
            choices = list(NUCL)
            choices.remove(seq[ix])
            res = random.choice(choices)
            seq = seq[:ix] + res + seq[ix + 1:]

        mutated[name] = seq

    return mutated


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
        '-i',
        dest='identity',
        type=float,
        default=IDENTITY,
        help=f'Target identity of the mutated sequence (default {IDENTITY})')
    args = parser.parse_args()

    return args


def main():
    """Do the thing."""
    args = get_args()
    print(f"Mutating {args.filename}...")

    fas = mutate(args)
    outfile = f"{args.filename.rsplit('.', 1)[0]}.mutated.fasta"
    fasta.write(fas, outfile)
    print(f"Mutation complete - saved to {outfile}")


if __name__ == '__main__':
    main()
