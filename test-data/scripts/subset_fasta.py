

# AUTHOR: Grace Hall <grace.hall1@unimelb.edu.au>

from __future__ import annotations
import argparse
from dataclasses import dataclass
from typing import Any, Callable, Protocol, TextIO, Optional


#######################
###  basic classes  ###
#######################

@dataclass
class Contig:
    header: str
    seq: str

class FastaFile:
    def __init__(self, contigs: list[Contig]):
        self.contigs = contigs

    def get(self, query: str, start: int, stop: int, strategy: ContigSearchStrategy) -> Contig:
        query = query.lstrip('>')
        contig = strategy.search(query, self.contigs)
        if not contig:
            raise RuntimeError(f'could not find contig with header starting with {query}')

        if start < 0 or start > len(contig.seq):
            raise IndexError('contig start position cannot be < 0 or greater than contig length')

        return Contig(contig.header, contig.seq[start: stop])


########################
## fasta file loading ##
########################

class FastaLoader:
    def __init__(self, esettings: ExecutionSettings):
        """creates a FastaFile from a file"""
        self.esettings = esettings
        self.fastas: list[Contig] = []

    def load(self) -> list[Contig]:
        """
        load function has to be very flexible. 
        file may be normal fasta format (header, seq) or can just be a bare sequence. 
        """
        self.fastas = []
        with open(self.esettings.fasta_path, 'r') as fp:
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
            self.fastas.append(Contig(header.lstrip('>'), sequence))


    
########################
### contig searching ###
########################

class ContigSearchStrategy(Protocol):
    def search(self, query: str, contigs: list[Contig]) -> Optional[Contig]:
        """
        searches contig dict for the contig which best matches the query str.  
        returns if found
        """
        ...


class FirstWordContigSearchStrategy:
    def search(self, query: str, contigs: list[Contig]) -> Optional[Contig]:
        """searches via checking if the query matches the first word of a contig header"""
        for contig in contigs:
            if contig.header == query:
                return contig
            elif ' ' in contig.header and contig.header.split(' ')[0] == query:
                return contig
        return None


class FlexibleContigSearchStrategy:
    def search(self, query: str, contigs: list[Contig]) -> Contig:
        """searches via local alignment of query to contig headers. returns best match score"""
        from Bio import pairwise2 # type: ignore
        scores: list[float] = []
        for contig in contigs:
            scores.append(self.local_align(query, contig.header, pairwise2.align.localxx)) # type: ignore
        
        best_match_index = scores.index(max(scores))
        return contigs[best_match_index]
        
    def local_align(self, pattern: str, template: str, align_func: Callable[[str, str], Any]) -> float:
        pattern = pattern.lower()
        template = template.lower()
        outcome = align_func(pattern, template)
        score = float(outcome[0].score) if len(outcome) > 0 else 0
        return score


#########################
## fasta output writer ##
#########################

class FastaWriter:
    def __init__(self, esettings: ExecutionSettings) -> None:
        self.esettings = esettings

    def write(self, contig: Contig) -> None:
        with open(self.esettings.output_path, 'w') as fp:
            header = contig.header
            seq = self.format_sequence(contig.seq)
            fp.write('>' + header + '\n')
            fp.write(seq + '\n')

    def format_sequence(self, seq: str) -> str:
        formatted_seq = ''
        for i in range(0, len(seq), self.esettings.output_line_width):
            formatted_seq += seq[i: i + self.esettings.output_line_width] + '\n'
        return formatted_seq


def main():
    # parse args
    esettings = parse_args()
    
    # load fasta file
    fl = FastaLoader(esettings)
    contigs = fl.load()
    
    ff = FastaFile(contigs)
    contig_subset = ff.get(
        esettings.contig_query, 
        esettings.contig_start, 
        esettings.contig_stop, 
        esettings.search_strategy
    )

    # write cleaned version
    fw = FastaWriter(esettings)
    fw.write(contig_subset)



#########################
### runtime settings  ###
#########################


class ExecutionSettings:
    def __init__(self, args: argparse.Namespace):
        self.fasta_path: str = args.fasta_path
        self.contig_query: str = args.contig_query
        self.output_path: str = args.fasta_path.rsplit('.', 1)[0] + '_subset.fasta'
        self.contig_start: int = 0
        self.contig_stop: int = -1
        self.output_line_width: int = 60
        self.search_strategy: ContigSearchStrategy = FirstWordContigSearchStrategy()
        self.update_settings(args)

    def update_settings(self, args: argparse.Namespace) -> None:
        if hasattr(args, 'outfile'):
            self.output_path = args.outfile
        if hasattr(args, 'begin'):
            self.contig_start = args.begin
        if hasattr(args, 'end'):
            self.contig_stop = args.end
        if hasattr(args, 'linewidth'):
            self.output_line_width = args.linewidth
        if hasattr(args, 'strategy') and args.strategy == 'flexible':
            self.search_strategy = FlexibleContigSearchStrategy()


def parse_args() -> ExecutionSettings:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "fasta_path", 
        help="input fasta file path", 
        type=str
    )   
    parser.add_argument(
        "contig_query", 
        help="first word of target contig header or a query string if using flexible search mode. used to select the desired contig from the fasta. do not include starting '>'", 
        type=str
    )   
    parser.add_argument(
        "-b", "--begin", 
        help="the beginning position in the target contig. leaving this blank begins at the beginning of the target contig.", 
        type=int
    )   
    parser.add_argument(
        "-e", "--end",
        help="the end position in the target contig. leaving this blank stops at the end of the target contig.", 
        type=int
    )   
    parser.add_argument(
        "-w", "--linewidth", 
        help="the fasta line width of the output (chars). default=60", 
        type=int
    )   
    parser.add_argument(
        '-s', '--strategy',
        type=str,
        help="strategy to find target contig. either --strategy firstword or --strategy flexible." 
    )   
    parser.add_argument(
        "-o", "--outfile",
        help="output fasta file path", 
        type=str
    )   
    args = parser.parse_args()
    return ExecutionSettings(args)



if __name__ == '__main__':
    main()