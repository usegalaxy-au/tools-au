"""Validate input FASTA sequence."""

import re
import sys
import argparse
from typing import List, TextIO


class Fasta:
    def __init__(self, header_str: str, seq_str: str):
        self.header = header_str
        self.aa_seq = seq_str


class FastaLoader:
    def __init__(self, fasta_path: str):
        """Initialize from FASTA file."""
        self.fastas = []
        self.load(fasta_path)

    def load(self, fasta_path: str):
        """Load bare or FASTA formatted sequence."""
        with open(fasta_path, 'r') as f:
            self.content = f.read()

        if "__cn__" in self.content:
            # Pasted content with escaped characters
            self.newline = '__cn__'
            self.read_caret = '__gt__'
        else:
            # Uploaded file with normal content
            self.newline = '\n'
            self.read_caret = '>'

        self.lines = self.content.split(self.newline)

        if not self.lines[0].startswith(self.read_caret):
            # Fasta is headless, load as single sequence
            self.update_fastas(
                '', ''.join(self.lines)
            )

        else:
            header = None
            sequence = None
            for line in self.lines:
                if line.startswith(self.read_caret):
                    if header:
                        self.update_fastas(header, sequence)
                    header = '>' + self.strip_header(line)
                    sequence = ''
                else:
                    sequence += line.strip('\n ')
            self.update_fastas(header, sequence)

    def strip_header(self, line):
        """Strip characters escaped with underscores from pasted text."""
        return re.sub(r'\_\_.{2}\_\_', '', line).strip('>')

    def update_fastas(self, header: str, sequence: str):
        # if we have a sequence
        if sequence:
            # create generic header if not exists
            if not header:
                fasta_count = len(self.fastas)
                header = f'>sequence_{fasta_count}'

            # Create new Fasta
            self.fastas.append(Fasta(header, sequence))


class FastaValidator:
    def __init__(
            self,
            fasta_list: List[Fasta],
            min_length=None,
            max_length=None):
        self.min_length = min_length
        self.max_length = max_length
        self.fasta_list = fasta_list
        self.iupac_characters = {
            'A', 'B', 'C', 'D', 'E', 'F', 'G',
            'H', 'I', 'K', 'L', 'M', 'N', 'P',
            'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
            'Y', 'Z', '-'
        }

    def validate(self):
        """performs fasta validation"""
        self.validate_num_seqs()
        self.validate_length()
        self.validate_alphabet()

        # not checking for 'X' nucleotides at the moment.
        # alphafold can throw an error if it doesn't like it.
        # self.validate_x()

    def validate_num_seqs(self) -> None:
        """Assert that only one sequence has been provided."""
        if len(self.fasta_list) > 1:
            raise Exception(
                'Error encountered validating fasta:'
                f' More than 1 sequence detected ({len(self.fasta_list)}).'
                ' Please use single fasta sequence as input.')
        elif len(self.fasta_list) == 0:
            raise Exception(
                'Error encountered validating fasta:'
                ' input file has no fasta sequences')

    def validate_length(self):
        """Confirm whether sequence length is valid."""
        fasta = self.fasta_list[0]
        if self.min_length:
            if len(fasta.aa_seq) < self.min_length:
                raise Exception(
                    'Error encountered validating fasta: Sequence too short'
                    f' ({len(fasta.aa_seq)}AA).'
                    f' Minimum length is {self.min_length}AA.')
        if self.max_length:
            if len(fasta.aa_seq) > self.max_length:
                raise Exception(
                    'Error encountered validating fasta:'
                    f' Sequence too long ({len(fasta.aa_seq)}AA).'
                    f' Maximum length is {self.max_length}AA.')

    def validate_alphabet(self):
        """
        Confirm whether the sequence conforms to IUPAC codes.
        If not, report the offending character and its position.
        """
        fasta = self.fasta_list[0]
        for i, char in enumerate(fasta.aa_seq.upper()):
            if char not in self.iupac_characters:
                raise Exception(
                    'Error encountered validating fasta: Invalid amino acid'
                    f' found at pos {i}: "{char}"')

    def validate_x(self):
        """Check for X bases."""
        fasta = self.fasta_list[0]
        for i, char in enumerate(fasta.aa_seq.upper()):
            if char == 'X':
                raise Exception(
                    'Error encountered validating fasta: Unsupported AA code'
                    f' "X" found at pos {i}')


class FastaWriter:
    def __init__(self) -> None:
        self.line_wrap = 60

    def write(self, fasta: Fasta):
        header = fasta.header
        seq = self.format_sequence(fasta.aa_seq)
        sys.stdout.write(header + '\n')
        sys.stdout.write(seq)

    def format_sequence(self, aa_seq: str):
        formatted_seq = ''
        for i in range(0, len(aa_seq), self.line_wrap):
            formatted_seq += aa_seq[i: i + self.line_wrap] + '\n'
        return formatted_seq


def main():
    # load fasta file
    args = parse_args()
    fas = FastaLoader(args.input)

    # validate
    fv = FastaValidator(
        fas.fastas,
        min_length=args.min_length,
        max_length=args.max_length,
    )
    fv.validate()

    # write cleaned version
    fw = FastaWriter()
    fw.write(fas.fastas[0])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input",
        help="input fasta file",
        type=str
    )
    parser.add_argument(
        "--min_length",
        dest='min_length',
        help="Minimum length of input protein sequence (AA)",
        default=None,
        type=int,
    )
    parser.add_argument(
        "--max_length",
        dest='max_length',
        help="Maximum length of input protein sequence (AA)",
        default=None,
        type=int,
    )
    return parser.parse_args()


if __name__ == '__main__':
    main()
