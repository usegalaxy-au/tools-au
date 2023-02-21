"""Generate additional output files not produced by AlphaFold.

Currently this is includes:
- model confidence scores
- per-residue confidence scores (pLDDTs - optional output)
- model_*.pkl files renamed with rank order

N.B. There have been issues with this script breaking between AlphaFold
versions due to minor changes in the output directory structure across minor
versions. It will likely need updating with future releases of AlphaFold.

This code is more complex than you might expect due to the output files
'moving around' considerably, depending on run parameters. You will see that
several output paths are determined dynamically.
"""

import argparse
import json
import os
import shutil
import pickle as pk
from pathlib import Path
from typing import List

# Output file names
OUTPUT_DIR = 'extra'
OUTPUTS = {
    'model_pkl': OUTPUT_DIR + '/model_{rank}.pkl',
    'model_confidence_scores': OUTPUT_DIR + '/model_confidence_scores.tsv',
    'plddts': OUTPUT_DIR + '/plddts.tsv',
}

# Keys for accessing confidence data from JSON/pkl files
# They change depending on whether the run was monomer or multimer
PLDDT_KEY = {
    'monomer': 'plddts',
    'multimer': 'iptm+ptm',
}


class Settings:
    """Parse and store settings/config."""
    def __init__(self):
        self.workdir = None
        self.output_confidence_scores = True
        self.output_residue_scores = False
        self.is_multimer = False

    def parse_settings(self) -> None:
        parser = argparse.ArgumentParser()
        parser.add_argument(
            "workdir",
            help="alphafold output directory",
            type=str
        )
        parser.add_argument(
            "-p",
            "--plddts",
            help="output per-residue confidence scores (pLDDTs)",
            action="store_true"
        )
        parser.add_argument(
            "-m",
            "--multimer",
            help="parse output from AlphaFold multimer",
            action="store_true"
        )
        parser.add_argument(
            "--model-pkl",
            dest="model_pkl",
            help="rename model pkl outputs with rank order",
            action="store_true"
        )
        args = parser.parse_args()
        self.workdir = Path(args.workdir.rstrip('/'))
        self.output_residue_scores = args.plddts
        self.output_model_pkls = args.model_pkl
        self.is_multimer = args.multimer
        self.output_dir = self.workdir / OUTPUT_DIR
        os.makedirs(self.output_dir, exist_ok=True)


class ExecutionContext:
    """Collect file paths etc."""
    def __init__(self, settings: Settings):
        self.settings = settings
        if settings.is_multimer:
            self.plddt_key = PLDDT_KEY['multimer']
        else:
            self.plddt_key = PLDDT_KEY['monomer']

    def get_model_key(self, ix: int) -> str:
        """Return json key for model index.

        The key format changed between minor AlphaFold versions so this
        function determines the correct key.
        """
        with open(self.ranking_debug) as f:
            data = json.load(f)
        model_keys = list(data[self.plddt_key].keys())
        for k in model_keys:
            if k.startswith(f"model_{ix}_"):
                return k
        return KeyError(
            f'Could not find key for index={ix} in'
            ' ranking_debug.json')

    @property
    def ranking_debug(self) -> str:
        return self.settings.workdir / 'ranking_debug.json'

    @property
    def model_pkl_paths(self) -> List[str]:
        return sorted([
            self.settings.workdir / f
            for f in os.listdir(self.settings.workdir)
            if f.startswith('result_model_') and f.endswith('.pkl')
        ])


class ResultModelPrediction:
    """Load and manipulate data from result_model_*.pkl files."""
    def __init__(self, path: str, context: ExecutionContext):
        self.context = context
        self.path = path
        self.name = os.path.basename(path).replace('result_', '').split('.')[0]
        with open(path, 'rb') as path:
            self.data = pk.load(path)

    @property
    def plddts(self) -> List[float]:
        """Return pLDDT scores for each residue."""
        return list(self.data['plddt'])


class ResultRanking:
    """Load and manipulate data from ranking_debug.json file."""

    def __init__(self, context: ExecutionContext):
        self.path = context.ranking_debug
        self.context = context
        with open(self.path, 'r') as f:
            self.data = json.load(f)

    @property
    def order(self) -> List[str]:
        """Return ordered list of model indexes."""
        return self.data['order']

    def get_plddt_for_rank(self, rank: int) -> List[float]:
        """Get pLDDT score for model instance."""
        return self.data[self.context.plddt_key][self.data['order'][rank - 1]]

    def get_rank_for_model(self, model: ResultModelPrediction) -> int:
        """Return 1-indexed rank for given model name.

        Model names are expressed in result_model_*.pkl file names.
        """
        return self.data['order'].index(model.name) + 1


def write_confidence_scores(ranking: ResultRanking, context: ExecutionContext):
    """Write per-model confidence scores."""
    print("Writing per-model confidence scores...")
    path = context.settings.workdir / OUTPUTS['model_confidence_scores']
    with open(path, 'w') as f:
        for rank in range(1, 6):
            score = ranking.get_plddt_for_rank(rank)
            f.write(f'model_{rank}\t{score:.2f}\n')


def write_per_residue_scores(
    ranking: ResultRanking,
    context: ExecutionContext,
):
    """Write per-residue plddts for each model.

    A row of plddt values is written for each model in tabular format.
    """
    model_plddts = {}
    for i, path in enumerate(context.model_pkl_paths):
        model = ResultModelPrediction(path, context)
        rank = ranking.get_rank_for_model(model)
        model_plddts[rank] = model.plddts

    path = context.settings.workdir / OUTPUTS['plddts']
    with open(path, 'w') as f:
        for i in sorted(list(model_plddts.keys())):
            print(f"Writing plddt row for key {i}...")
            row = [f'model_{i}'] + [
                str(x) for x in model_plddts[i]
            ]
            f.write('\t'.join(row) + '\n')


def rename_model_pkls(ranking: ResultRanking, context: ExecutionContext):
    """Rename model.pkl files so the rank order is implicit."""
    for path in context.model_pkl_paths:
        model = ResultModelPrediction(path, context)
        rank = ranking.get_rank_for_model(model)
        new_path = (
            context.settings.workdir
            / OUTPUTS['model_pkl'].format(rank=rank)
        )
        shutil.copyfile(path, new_path)


def main():
    """Parse output files and generate additional output files."""
    settings = Settings()
    settings.parse_settings()
    context = ExecutionContext(settings)
    ranking = ResultRanking(context)
    write_confidence_scores(ranking, context)

    # Optional outputs
    if settings.output_model_pkls:
        rename_model_pkls(ranking, context)

    if settings.output_residue_scores:
        write_per_residue_scores(ranking, context)


if __name__ == '__main__':
    main()
