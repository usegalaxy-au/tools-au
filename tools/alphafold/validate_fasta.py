

import sys


class Fasta:
    def __init__(self, header_str, seq_str):
        self.header = Header(header_str)
        self.seq = AASequence(seq_str)


    def validate(self):
        """
        Checks for aa sequence validity. raises exceptions if invalid. 
        """
        self.seq.validate_length()
        self.seq.validate_alphabet()
        self.seq.validate_x()



class Header:
    def __init__(self, header):
        self.text = header



class AASequence:
    def __init__(self, sequence):
        self.text = sequence
        self.length = len(sequence)
        self.min_length = 30
        self.max_length = 2000
        self.formatted_line_len = 60


    def get_formatted_sequence(self):
        formatted_seq = ''
        line_len = self.formatted_line_len
        for i in range(0, len(self.text), line_len):
            formatted_seq += self.text[i: i + line_len] + '\n'

        return formatted_seq


    def validate_length(self):
        """
        Confirms whether sequence length is valid. 
        If not, reports. 
        """ 
        if self.length < self.min_length:
            raise Exception(f'Error encountered validating fasta. Sequence too short ({self.length}aa). Must be > 30aa')
        if self.length > self.max_length:
            raise Exception(f'Error encountered validating fasta. Sequence too long ({self.length}aa). Must be < 2000aa')

    
    def validate_alphabet(self):
        """
        Confirms whether the sequence conforms to IUPAC codes. 
        If not, reports the offending character and its position. 
        """ 
        iupac_characters = {
            'A', 'B', 'C', 'D', 'E', 'F', 'G', 
            'H', 'I', 'K', 'L', 'M', 'N', 'P', 
            'Q', 'R', 'S', 'T', 'V', 'W', 'X', 
            'Y', 'Z'
        }

        seq = self.text.upper()

        for i, char in enumerate(seq):
            if char not in iupac_characters:
                raise Exception(f'Error encountered validating fasta. Invalid amino acid found at pos {i}: {char}')

    
    def validate_x(self):
        """
        checks if any bases are X. TODO check whether alphafold accepts X bases. 
        """ 
        seq = self.text.upper()

        for i, char in enumerate(seq):
            if char == 'X':
                raise Exception(f'Error encountered validating fasta. Unsupported aa code "X" found at pos {i}')



class FastaLoader:
    def __init__(self, filepath):
        self.filepath = filepath
        self.fastas = []


    def load(self):
        """
        load function has to be very flexible. 
        file may be normal fasta format (header, seq) or can just be a bare sequence. 
        """
        with open(self.filepath, 'r') as fp:
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


    def interpret_first_line(self, fp):
        header = ''
        sequence = ''
        line = fp.readline().rstrip('\n')
        if line.startswith('>'):
            header = line
        else:
            sequence += line

        return header, sequence
                

    def update_fastas(self, header, sequence):
        # if we have a sequence
        if not sequence == '':
            
            # create generic header if not exists
            if header == '':
                fasta_count = len(self.fastas)
                header = f'>sequence_{fasta_count}'
            
            # create new Fasta    
            new_fasta = Fasta(header, sequence)
            self.fastas.append(new_fasta)



def main(argv):
    filepath = argv[0]
    input_type = argv[1]

    if input_type == 'text':
        verify_text(filepath)
    
    fl = FastaLoader(filepath)
    fastas = fl.load()

    verify_num_fastas(fastas)
    verify_fasta_content(fastas[0])
    write_fasta(fastas[0])


def verify_text(filepath):
    with open(filepath, 'r') as fp:
        line = fp.readline()
        if line[0] == '>':
            raise Exception('Please remove header line from pasted protein sequence')


def verify_num_fastas(fastas):
    if len(fastas) == 0:
        raise Exception(f'no fasta sequence detected')
    elif len(fastas) > 1:
        raise Exception(f'Error encountered validating fasta. More than 1 sequence detected ({len(fastas)}). Please use single fasta sequence as input')


def verify_fasta_content(fasta):
    fasta.validate()


def write_fasta(fasta):
    with open('alphafold.fasta', 'w') as fp:
        header = fasta.header.text
        seq = fasta.seq.get_formatted_sequence()
        fp.write(header + '\n')
        fp.write(seq + '\n')




if __name__ == '__main__':
    main(sys.argv[1:])