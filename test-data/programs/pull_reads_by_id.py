



# this program is slightly disgusting but very fast (for python) and consumes essentially zero memory. 



def main():
    assert_firstline()
    pull_reads()


def assert_firstline(fastq_path: str):
    with open(fastq_path, 'r') as fp:
        line = fp.readline()
        if not line.startswith('>'):
            raise RuntimeError('fastq does not start with ">"')


def pull_reads(fastq_path: str, read_ids: set[str], out_path: str) -> None:
    with open(fastq_path, 'r') as in_fp:
        with open(out_path, 'w') as out_fp:
            header = in_fp.readline()
            
            while header:
                if header.lstrip('>') in read_ids:
                    out_fp.write(header + '\n')
                    out_fp.write(in_fp.readline() + '\n')
                    out_fp.write(in_fp.readline() + '\n')
                    out_fp.write(in_fp.readline() + '\n')
                else:
                    next(in_fp)
                    next(in_fp)
                    next(in_fp)
                
                header = in_fp.readline()
            


if __name__ == '__main__':
    main()


