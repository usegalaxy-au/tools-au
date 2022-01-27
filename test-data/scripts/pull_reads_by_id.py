
# AUTHOR: Grace Hall <grace.hall1@unimelb.edu.au>


import argparse
from dataclasses import dataclass
import re
from typing import Optional




@dataclass
class IOFilePair:
    inp: str
    out: str

class ExecutionSettings:
    def __init__(self, args: argparse.Namespace):
        self.args = args

    def is_paired_end(self) -> bool:
        """should be private"""
        if not self.args.reads:
            if self.args.forward and self.args.reverse:
                return True
        return False

    def get_read_ids_path(self) -> str:
        return self.args.ids

    def get_io_pair(self, orientation: Optional[str] = None) -> IOFilePair:
        """
        public method to get in and out filepair names.
        depends on whether we are using single / paired reads
        """
        args = self.args
        # fwd or rev paired
        if self.is_paired_end and orientation:
            if orientation == 'forward':
                return IOFilePair(
                    args.forward, 
                    self.make_outfile_name(args.forward, args.out, append='_1')
                )
            elif orientation == 'reverse':
                return IOFilePair(
                    args.reverse, 
                    self.make_outfile_name(args.reverse, args.out, append='_2')
                )
            else:
                raise RuntimeError()  # TODO
        # single end
        else:
            return IOFilePair(
                args.reads, 
                self.make_outfile_name(args.reads, args.out)
            )

    def make_outfile_name(self, input: str, output: str, append: str='') -> str:
        """
        creates an outfile path. if no output is given, it templates one
        from the input filepath
        """
        if output:
            return output.rsplit('.', 1)[0] + append + '.fastq'
        else:
            in_path = re.sub(f'{append}$', '', input.rsplit('.', 1)[0])
            return in_path + append + '.fastq'


def main():
    args = parse_args()
    assert_args(args)
    esettings = ExecutionSettings(args)
    read_ids = load_read_ids(esettings.get_read_ids_path())

    if args.reads:
        read_write(read_ids, esettings.get_io_pair())

    elif args.forward and args.reverse:
        read_write(read_ids, esettings.get_io_pair(orientation='forward'))
        read_write(read_ids, esettings.get_io_pair(orientation='reverse'))
   

def load_read_ids(filepath: str) -> set[str]:
    with open(filepath, 'r') as fp:
        read_ids = fp.readlines()
        read_ids = [ident.strip('\n\t@') for ident in read_ids]
        return set(read_ids)


def read_write(read_ids: set[str], files: IOFilePair) -> None:
    with open(files.inp, 'r') as in_fp:
        with open(files.out, 'w') as out_fp:
            header = in_fp.readline()
            
            while header:
                if header.lstrip('@').split()[0] in read_ids:
                    out_fp.write(header)
                    out_fp.write(in_fp.readline())
                    out_fp.write(in_fp.readline())
                    out_fp.write(in_fp.readline())
                else:
                    next(in_fp)
                    next(in_fp)
                    next(in_fp)
                
                header = in_fp.readline()
            

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-r", "--reads", 
        help="input fastq reads file path. For single end sequences", 
        type=str
    )   
    parser.add_argument(
        "-F", "--forward", 
        help="forward reads file path - used for paired end sequencing. must also declare --reverse reads file.", 
        type=str
    )   
    parser.add_argument(
        "-R", "--reverse", 
        help="reverse reads file path - used for paired end sequencing. must also declare --forward reads file.", 
        type=str
    )   
    parser.add_argument(
        "-i", "--ids", 
        help="read ids to extract. should be txt file with 1 read id per line. if paired-end sequencing, the read ideas will be extracted from both fwd and rev fastq files. ", 
        type=str
    )   
    parser.add_argument(
        "-o", "--out", 
        help="output fastq file path. if paired-end sequencing, will add '_1' and '_2' extensions on the filename. if not specified, will use the input reads filename.", 
        type=str
    )   
    return parser.parse_args()


def assert_args(args: argparse.Namespace) -> None:
    # has correct read inputs
    if not args.reads:
        if not args.forward or not args.reverse:
            raise RuntimeError('either --reads or both --forward and --reverse need to be set')
    
    # has too many read inputs
    if args.reads:
        if args.forward or args.reverse: 
            raise RuntimeError('--reads cannot be used in conjunction with --forward or --reverse')

    # no read ids
    if not args.ids:
        raise RuntimeError('--ids must specify a path to a txtfile containing the read ids of reads to extract')

    if args.reads:
        assert_firstline(args.reads)
    elif args.forward and args.reverse:
        assert_firstline(args.forward)
        assert_firstline(args.reverse)
    
       
def assert_firstline(fastq_path: str) -> None:
    with open(fastq_path, 'r') as fp:
        line = fp.readline()
        if not line.startswith('@'):
            raise RuntimeError('fastq does not start with "@"')


if __name__ == '__main__':
    main()


