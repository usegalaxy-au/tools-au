

import json
import pickle
import argparse
from typing import Any, Dict, List


class Settings:
    """parses then keeps track of program settings"""
    def __init__(self):
        self.workdir = None
        self.output_confidence_scores = True
        self.output_residue_scores = False

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
        args = parser.parse_args()
        self.workdir = args.workdir.rstrip('/')
        self.output_residue_scores = args.plddts


class ExecutionContext:
    """uses program settings to get paths to files etc"""
    def __init__(self, settings: Settings):
        self.settings = settings

    @property
    def ranking_debug(self) -> str:
        return f'{self.settings.workdir}/ranking_debug.json'

    @property
    def model_pkls(self) -> List[str]:
        return [f'{self.settings.workdir}/result_model_{i}.pkl'
                for i in range(1, 6)]

    @property
    def model_conf_score_output(self) -> str:
        return f'{self.settings.workdir}/model_confidence_scores.tsv'

    @property
    def plddt_output(self) -> str:
        return f'{self.settings.workdir}/plddts.tsv'


class FileLoader:
    """loads file data for use by other classes"""
    def __init__(self, context: ExecutionContext):
        self.context = context

    def get_model_mapping(self) -> Dict[str, int]:
        data = self.load_ranking_debug()
        return {name: int(rank) + 1 
                for (rank, name) in enumerate(data['order'])}

    def get_conf_scores(self) -> Dict[str, float]:
        data = self.load_ranking_debug()
        return {name: float(f'{score:.2f}') 
                for name, score in data['plddts'].items()}

    def load_ranking_debug(self) -> Dict[str, Any]:
        with open(self.context.ranking_debug, 'r') as fp:
            return json.load(fp)

    def get_model_plddts(self) -> Dict[str, List[float]]:
        plddts: Dict[str, List[float]] = {}
        model_pkls = self.context.model_pkls
        for i in range(5):
            pklfile = model_pkls[i]
            with open(pklfile, 'rb') as fp:
                data = pickle.load(fp)
                plddts[f'model_{i+1}'] = [float(f'{x:.2f}') for x in data['plddt']]
        return plddts


class OutputGenerator:
    """generates the output data we are interested in creating"""
    def __init__(self, loader: FileLoader):
        self.loader = loader

    def gen_conf_scores(self):
        mapping = self.loader.get_model_mapping()
        scores = self.loader.get_conf_scores()
        ranked = list(scores.items())
        ranked.sort(key=lambda x: x[1], reverse=True)
        return {f'model_{mapping[name]}': score 
                for name, score in ranked}

    def gen_residue_scores(self) -> Dict[str, List[float]]:
        mapping = self.loader.get_model_mapping()
        model_plddts = self.loader.get_model_plddts()
        return {f'model_{mapping[name]}': plddts 
                for name, plddts in model_plddts.items()}


class OutputWriter:
    """writes generated data to files"""
    def __init__(self, context: ExecutionContext):
        self.context = context

    def write_conf_scores(self, data: Dict[str, float]) -> None:
        outfile = self.context.model_conf_score_output
        with open(outfile, 'w') as fp:
            for model, score in data.items():
                fp.write(f'{model}\t{score}\n')
    
    def write_residue_scores(self, data: Dict[str, List[float]]) -> None:
        outfile = self.context.plddt_output
        model_plddts = list(data.items())
        model_plddts.sort()

        with open(outfile, 'w') as fp:
            for model, plddts in model_plddts:
                plddt_str_list = [str(x) for x in plddts]
                plddt_str = ','.join(plddt_str_list)
                fp.write(f'{model}\t{plddt_str}\n')


def main():
    # setup
    settings = Settings()
    settings.parse_settings()
    context = ExecutionContext(settings)
    loader = FileLoader(context)
    
    # generate & write outputs
    generator = OutputGenerator(loader)
    writer = OutputWriter(context)
    
    # confidence scores
    conf_scores = generator.gen_conf_scores()
    writer.write_conf_scores(conf_scores)
    
    # per-residue plddts
    if settings.output_residue_scores:
        residue_scores = generator.gen_residue_scores()
        writer.write_residue_scores(residue_scores)

    
if __name__ == '__main__':
    main()



