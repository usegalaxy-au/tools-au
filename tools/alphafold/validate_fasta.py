"""Validate input FASTA sequence."""

import re
import sys
import argparse
from typing import List

MULTIMER_MAX_SEQUENCE_COUNT = 10


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
            min_length=None,
            max_length=None,
            multiple=False):
        self.multiple = multiple
        self.min_length = min_length
        self.max_length = max_length
        self.iupac_characters = {
            'A', 'B', 'C', 'D', 'E', 'F', 'G',
            'H', 'I', 'K', 'L', 'M', 'N', 'P',
            'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
            'Y', 'Z', '-'
        }

    def validate(self, fasta_list: List[Fasta]):
        """Perform FASTA validation."""
        self.fasta_list = fasta_list
        self.validate_num_seqs()
        self.validate_length()
        self.validate_alphabet()
        # not checking for 'X' nucleotides at the moment.
        # alphafold can throw an error if it doesn't like it.
        # self.validate_x()
        return self.fasta_list

    def validate_num_seqs(self) -> None:
        """Assert that only one sequence has been provided."""
        fasta_count = len(self.fasta_list)

        if self.multiple:
            if fasta_count < 2:
                raise ValueError(
                    'Error encountered validating FASTA:\n'
                    'Multimer mode requires multiple input sequence.'
                    f' Only {fasta_count} sequences were detected in'
                    ' the provided file.')
                self.fasta_list = self.fasta_list

            elif fasta_count > MULTIMER_MAX_SEQUENCE_COUNT:
                sys.stderr.write(
                    f'WARNING: detected {fasta_count} sequences but the'
                    f' maximum allowed is {MULTIMER_MAX_SEQUENCE_COUNT}'
                    ' sequences. The last'
                    f' {fasta_count - MULTIMER_MAX_SEQUENCE_COUNT} sequence(s)'
                    ' have been discarded.\n')
                self.fasta_list = self.fasta_list[:MULTIMER_MAX_SEQUENCE_COUNT]
        else:
            if fasta_count > 1:
                sys.stderr.write(
                    'WARNING: More than 1 sequence detected.'
                    ' Using first FASTA sequence as input.\n')
                self.fasta_list = self.fasta_list[:1]

            elif len(self.fasta_list) == 0:
                raise ValueError(
                    'Error encountered validating FASTA:\n'
                    ' no FASTA sequences detected in input file.')

    def validate_length(self):
        """Confirm whether sequence length is valid."""
        fasta = self.fasta_list[0]
        if self.min_length:
            if len(fasta.aa_seq) < self.min_length:
                raise ValueError(
                    'Error encountered validating FASTA:\n Sequence too short'
                    f' ({len(fasta.aa_seq)}AA).'
                    f' Minimum length is {self.min_length}AA.')
        if self.max_length:
            if len(fasta.aa_seq) > self.max_length:
                raise ValueError(
                    'Error encountered validating FASTA:\n'
                    f' Sequence too long ({len(fasta.aa_seq)}AA).'
                    f' Maximum length is {self.max_length}AA.')

    def validate_alphabet(self):
        """Confirm whether the sequence conforms to IUPAC codes.

        If not, report the offending character and its position.
        """
        fasta = self.fasta_list[0]
        for i, char in enumerate(fasta.aa_seq.upper()):
            if char not in self.iupac_characters:
                raise ValueError(
                    'Error encountered validating FASTA:\n Invalid amino acid'
                    f' found at pos {i}: "{char}"')

    def validate_x(self):
        """Check for X bases."""
        fasta = self.fasta_list[0]
        for i, char in enumerate(fasta.aa_seq.upper()):
            if char == 'X':
                raise ValueError(
                    'Error encountered validating FASTA:\n Unsupported AA code'
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
        return formatted_seq.upper()


def main():
    # load fasta file
    try:
        args = parse_args()
        fas = FastaLoader(args.input)

        # validate
        fv = FastaValidator(
            min_length=args.min_length,
            max_length=args.max_length,
            multiple=args.multimer,
        )
        clean_fastas = fv.validate(fas.fastas)

        # write clean data
        fw = FastaWriter()
        for fas in clean_fastas:
            fw.write(fas)

    except ValueError as exc:
        sys.stderr.write(f"{exc}\n\n")
        raise exc

    except Exception as exc:
        sys.stderr.write(
            "Input error: FASTA input is invalid. Please check your input.\n\n"
        )
        raise exc


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
    parser.add_argument(
        "--multimer",
        action='store_true',
        help="Require multiple input sequences",
    )
    return parser.parse_args()


if __name__ == '__main__':
    main()
