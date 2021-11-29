

import json
import pickle
import sys
import numpy as np


class FileLoader:
    def __init__(self):
        self.workdir = 'output/alphafold'
        self.model_mapping = {}
        self.model_scores = {}
        self.model_plddts = {}


    def load_conf_scores(self):
        filepath = f'{self.workdir}/ranking_debug.json'
        with open(filepath, 'r') as fp:
            data = json.load(fp)

        self.set_model_mapping(data)
        self.set_model_scores(data)
        print()


    def set_model_mapping(self, data):
        for rank, model_name in enumerate(data['order']):
            self.model_mapping[model_name] = f'ranked_{rank}'


    def set_model_scores(self, data):
        for model_name, conf_score in data['plddts'].items():
            self.model_scores[model_name] = conf_score


    def load_model_plddts(self):
        data = {}
        for i in range(5):
            filepath = f'{self.workdir}/result_model_{i+1}.pkl'
            with open(filepath, 'rb') as fp:
                data[f'model_{i+1}'] = pickle.load(fp)
        
        self.set_model_plddts(data)


    def set_model_plddts(self, data):
        for model_name, info in data.items():
            plddt_scores = info['plddt']
            plddt_scores = [f'{x:.2f}' for x in plddt_scores]
            self.model_plddts[model_name] = ','.join(plddt_scores)



class FileWriter:
    def __init__(self):
        self.outdir = 'output/alphafold'


    def write_conf_scores(self, model_mapping, model_scores):
        out_lines = []

        # for each model, translate its name, then format a line to write
        models_ranked = list(model_scores.items())
        models_ranked.sort(key=lambda x: x[1], reverse=True)

        for model_name, score in models_ranked:
            ranked_name = model_mapping[model_name]
            out_lines.append(f'{ranked_name}\t{score}')

        # write
        header = 'model\tconfidence score'
        filepath = f'{self.outdir}/model_confidence_scores.tsv'
        self.write_tsv(header, out_lines, filepath)
       

    def write_tsv(self, header, tsv_data, filepath):
        """
        tsv_data is expected in the form of a list of tuples where each tuple has form [model_name, data]
        """
        with open(filepath, 'w') as fp:
            fp.write(header + '\n')
            for line in tsv_data:
                fp.write(f'{line}\n')
        

    def write_model_plddts(self, model_mapping, model_plddts):
        out_lines = []

        # for each model, translate its name, then format a line to write
        ranked_plddts = []
        for model_name, plddt_string in model_plddts.items():
            ranked_name = model_mapping[model_name]
            ranked_plddts.append([ranked_name, plddt_string])
        
        ranked_plddts.sort(key=lambda x: int(x[0][-1]))

        out_lines = [f'{m}\t{p}' for m, p in ranked_plddts]

        # write
        header = 'model\tper-residue confidence score (pLDDT)'
        filepath = f'{self.outdir}/plddts.tsv'
        self.write_tsv(header, out_lines, filepath)
    


def main(argv):
    extra_outputs = argv[0].split(',')  # 'plddts,msas'
    fl = FileLoader()
    fw = FileWriter()
    
    # model confidence scores
    fl.load_conf_scores()
    fw.write_conf_scores(fl.model_mapping, fl.model_scores)

    # per-residue confidence scores
    if 'plddts' in extra_outputs:
        fl.load_model_plddts()
        fw.write_model_plddts(fl.model_mapping, fl.model_plddts)

    
    
if __name__ == '__main__':
    main(sys.argv[1:])



