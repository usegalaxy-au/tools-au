import Levenshtein

x = """  File "/opt/conda/lib/python3.7/site-packages/absl/app.py", line 312, in run
    _run_main(main, args)
  File "/opt/conda/lib/python3.7/site-packages/absl/app.py", line 258, in _run_main
    sys.exit(main(argv))
  File "/app/alphafold/run_alphafold.py", line 429, in main
    is_prokaryote=is_prokaryote)
  File "/app/alphafold/run_alphafold.py", line 250, in predict_structure
    relaxed_pdb_str, _, _ = amber_relaxer.process(prot=unrelaxed_protein)
  File "/app/alphafold/alphafold/relax/relax.py", line 66, in process
    use_gpu=self._use_gpu)
  File "/app/alphafold/alphafold/relax/amber_minimize.py", line 466, in run_pipeline
    _check_residues_are_well_defined(prot)
  File "/app/alphafold/alphafold/relax/amber_minimize.py", line 141, in _check_residues_are_well_defined
    raise ValueError("Amber minimization can only be performed on proteins with"
ValueError: Amber minimization can only be performed on proteins with well-defined residues. This protein contains at least one residue with no atoms.
"""

y = """Multimer mode requires multiple input sequence. Only 1 sequences were detected in the provided file.

Traceback (most recent call last):
  File "/mnt/pulsar/files/staging/5416816/tool_files/validate_fasta.py", line 249, in <module>
    main()
  File "/mnt/pulsar/files/staging/5416816/tool_files/validate_fasta.py", line 210, in main
    raise exc
  File "/mnt/pulsar/files/staging/5416816/tool_files/validate_fasta.py", line 201, in main
    clean_fastas = fv.validate(fas.fastas)
  File "/mnt/pulsar/files/staging/5416816/tool_files/validate_fasta.py", line 93, in validate
    self.validate_num_seqs()
  File "/mnt/pulsar/files/staging/5416816/tool_files/validate_fasta.py", line 108, in validate_num_seqs
    'Error encountered validating FASTA:\n'
ValueError: Error encountered validating FASTA:
Multimer mode requires multiple input sequence. Only 1 sequences were detected in the provided file.
"""

z = """Multimer mode requires multiple input sequence. Only 1 sequences were detected in the provided file.

Traceback (most recent call last):
  File "/mnt/pulsar/files/staging/5382817/tool_files/validate_fasta.py", line 249, in <module>
    main()
  File "/mnt/pulsar/files/staging/5382817/tool_files/validate_fasta.py", line 210, in main
    raise exc
  File "/mnt/pulsar/files/staging/5382817/tool_files/validate_fasta.py", line 201, in main
    clean_fastas = fv.validate(fas.fastas)
  File "/mnt/pulsar/files/staging/5382817/tool_files/validate_fasta.py", line 93, in validate
    self.validate_num_seqs()
  File "/mnt/pulsar/files/staging/5382817/tool_files/validate_fasta.py", line 108, in validate_num_seqs
    'Error encountered validating FASTA:\n'
ValueError: Error encountered validating FASTA:
Multimer mode requires multiple input sequence. Only 1 sequences were detected in the provided file.
"""

# Different
print("X:Y - ", Levenshtein.ratio(x, y))

# Similar
print("Y:Z - ", Levenshtein.ratio(y, z))
