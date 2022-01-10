

import argparse
from typing import List, TextIO


class Fasta:
    def __init__(self, header_str: str, seq_str: str):
        self.header = header_str
        self.aa_seq = seq_str


class FastaLoader:
    def __init__(self):
        """creates a Fasta() from a file"""
        self.fastas: List[Fasta] = []

    def load(self, fasta_path: str):
        """
        load function has to be very flexible. 
        file may be normal fasta format (header, seq) or can just be a bare sequence. 
        """
        with open(fasta_path, 'r') as fp:
            header, sequence = self.interpret_first_line(fp)
            line = fp.readline().rstrip('\n')
        
            while line:
                if line.startswith('>'):
                    self.update_fastas(header, sequence)
                    header = line
                    sequence = ''
                else:
                    sequence += line
                line = fp.readline().rstrip('\n')

        # after reading whole file, header & sequence buffers might be full
        self.update_fastas(header, sequence)
        return self.fastas

    def interpret_first_line(self, fp: TextIO):
        header = ''
        sequence = ''
        line = fp.readline().rstrip('\n')
        if line.startswith('>'):
            header = line
        else:
            sequence += line
        return header, sequence
                
    def update_fastas(self, header: str, sequence: str):
        # if we have a sequence
        if not sequence == '':
            # create generic header if not exists
            if header == '':
                fasta_count = len(self.fastas)
                header = f'>sequence_{fasta_count}'

            # create new Fasta    
            self.fastas.append(Fasta(header, sequence))


class FastaValidator:
    def __init__(self, fasta_list: List[Fasta]):
        self.fasta_list = fasta_list
        self.min_length = 30
        self.max_length = 2000
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
        #self.validate_x() 

    def validate_num_seqs(self) -> None:
        if len(self.fasta_list) > 1:
            raise Exception(f'Error encountered validating fasta: More than 1 sequence detected ({len(self.fasta_list)}). Please use single fasta sequence as input')
        elif len(self.fasta_list) == 0:
            raise Exception(f'Error encountered validating fasta: input file has no fasta sequences')

    def validate_length(self):
        """Confirms whether sequence length is valid. """
        fasta = self.fasta_list[0]
        if len(fasta.aa_seq) < self.min_length:
            raise Exception(f'Error encountered validating fasta: Sequence too short ({len(fasta.aa_seq)}aa). Must be > 30aa')
        if len(fasta.aa_seq) > self.max_length:
            raise Exception(f'Error encountered validating fasta: Sequence too long ({len(fasta.aa_seq)}aa). Must be < 2000aa')
    
    def validate_alphabet(self):
        """
        Confirms whether the sequence conforms to IUPAC codes. 
        If not, reports the offending character and its position. 
        """ 
        fasta = self.fasta_list[0]
        for i, char in enumerate(fasta.aa_seq.upper()):
            if char not in self.iupac_characters:
                raise Exception(f'Error encountered validating fasta: Invalid amino acid found at pos {i}: {char}')

    def validate_x(self):
        """checks if any bases are X. TODO check whether alphafold accepts X bases. """ 
        fasta = self.fasta_list[0]
        for i, char in enumerate(fasta.aa_seq.upper()):
            if char == 'X':
                raise Exception(f'Error encountered validating fasta: Unsupported aa code "X" found at pos {i}')


class FastaWriter:
    def __init__(self) -> None:
        self.outfile = 'alphafold.fasta'
        self.formatted_line_len = 60

    def write(self, fasta: Fasta):
        with open(self.outfile, 'w') as fp:
            header = fasta.header
            seq = self.format_sequence(fasta.aa_seq)
            fp.write(header + '\n')
            fp.write(seq + '\n')

    def format_sequence(self, aa_seq: str):
        formatted_seq = ''
        for i in range(0, len(aa_seq), self.formatted_line_len):
            formatted_seq += aa_seq[i: i + self.formatted_line_len] + '\n'
        return formatted_seq


def main():
    # load fasta file
    args = parse_args()
    fl = FastaLoader()
    fastas = fl.load(args.input_fasta)

    # validate
    fv = FastaValidator(fastas)
    fv.validate()

    # write cleaned version
    fw = FastaWriter()
    fw.write(fastas[0])

        
def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_fasta", 
        help="input fasta file", 
        type=str
    )   
    return parser.parse_args()



if __name__ == '__main__':
    main()