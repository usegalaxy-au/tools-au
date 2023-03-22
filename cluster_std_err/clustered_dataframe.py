#!/usr/bin/env python3

from nltk import word_tokenize, download
from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer
from sklearn.cluster import DBSCAN
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from transformers import AutoTokenizer, AutoModel
import Levenshtein
import numpy as np
import pandas as pd
import torch


class ClusteredDataFrame(pd.DataFrame):
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
        if 'std_err' not in self.columns:
            raise ValueError(
                "The 'std_err' column is missing from the DataFrame.")

        # create list of error messages for quick access
        self.error_messages = self['std_err'].tolist()
        # tokenise the errors
        self.tokenize_err()

        # Run the similarity calculations
        self.compute_wmd_similarity()
        self.compute_levenshtein_similarity()
        self.compute_jaccard_similarity()
        self.compute_tfidf_similarity()

        # Add the cluster IDs
        self.cluster_errors()

    def tokenize_err(self):
        # Download stopwords and WordNet lemmatizer if necessary
        download('stopwords')
        download('wordnet')
        stop_words = set(stopwords.words('english'))
        lemmatizer = WordNetLemmatizer()

        # Pre-process error messages
        preprocessed_errors = []
        for error in self.error_messages:
            # Tokenize
            tokens = word_tokenize(error.lower())

            # Remove stop words and non-alphabetic characters, and lemmatize
            filtered_tokens = [lemmatizer.lemmatize(t)
                               for t in tokens
                               if t.isalpha() and t not in stop_words]

            preprocessed_errors.append(' '.join(filtered_tokens))
        self['tokenized_err'] = preprocessed_errors

    def compute_wmd_similarity(self, model_name: str):
        """
        Computes the Word Mover's Distance (WMD) similarity between error
        messages using the specified pre-trained model.

        Parameters:
            error_messages (List[str]): List of error messages to cluster.
            model_name (str): Name of the pre-trained model to use.
            Options: 'codebert', 'codegpt'.

        Returns:
            np.ndarray: Similarity matrix, where the (i, j) element is the WMD
            similarity between error_messages[i] and error_messages[j].
        """
        if model_name not in ('codebert', 'codegpt'):
            raise ValueError("Invalid pre-trained model name. Options: 'codebert', 'codegpt'.")

        # Load pre-trained model and tokenizer
        if model_name == 'codebert':
            model = AutoModel.from_pretrained('microsoft/codeberta-base')
        else:  # model_name == 'codegpt'
            model = AutoModel.from_pretrained('microsoft/codegpt-small-java')

        tokenizer = AutoTokenizer.from_pretrained(model_name)

        # Pre-process error messages and compute word embeddings
        embeddings = []
        tokenized_errors = []
        error_messages = self.error_messages

        for error in error_messages:
            # Tokenize and convert to input IDs
            tokens = tokenizer(
                error,
                return_tensors='pt',
                padding=True,
                truncation=True)
            input_ids = tokens['input_ids']

            # Get word embeddings from pre-trained model
            with torch.no_grad():
                output = model(input_ids)
                if model_name == 'codebert':
                    embeddings.append(output.last_hidden_state[:, 0, :].numpy())
                else:  # model_name == 'codegpt'
                    embeddings.append(output[0][:, -1, :].numpy())

            # Save tokenized error for later use
            tokenized_errors.append(tokenizer.tokenize(error))

        # Compute similarity matrix using Word Mover's Distance
        sim_matrix = np.zeros((len(embeddings), len(embeddings)))
        for i in range(len(embeddings)):
            for j in range(i, len(embeddings)):
                if i == j:
                    sim_matrix[i, j] = 1.0
                else:
                    distance = model.wmdistance(
                        tokenized_errors[i],
                        tokenized_errors[j])
                    sim_matrix[i, j] = sim_matrix[j, i] = 1 / (1 + distance)
            
        # Store the similarity matrix in the object
        self.wmd_similarity_matrix = sim_matrix

    def compute_levenshtein_similarity(self):
        preprocessed_errors = self.tokenized_err
        sim_matrix = np.zeros(
            (len(preprocessed_errors),
             len(preprocessed_errors)))
        for i in range(len(preprocessed_errors)):
            for j in range(i, len(preprocessed_errors)):
                sim_matrix[i, j] = sim_matrix[j, i] = 1 - Levenshtein.distance(
                    preprocessed_errors[i], preprocessed_errors[j]) / max(
                    len(preprocessed_errors[i]), len(preprocessed_errors[j]))
        self.levenshtein_similarity_matrix = sim_matrix

    def compute_jaccard_similarity(self):
        preprocessed_errors = self.tokenized_err
        sim_matrix = np.zeros(
            (len(preprocessed_errors),
             len(preprocessed_errors)))
        for i in range(len(preprocessed_errors)):
            for j in range(i, len(preprocessed_errors)):
                set_i = set(preprocessed_errors[i].split())
                set_j = set(preprocessed_errors[j].split())
                intersection = set_i.intersection(set_j)
                union = set_i.union(set_j)
                sim = len(intersection) / len(union)
                sim_matrix[i, j] = sim_matrix[j, i] = sim
        self.jaccard_similarity_matrix = sim_matrix

    def compute_tfidf_similarity(self):
        preprocessed_errors = self.tokenized_err
        vectorizer = TfidfVectorizer()
        tf_idf_matrix = vectorizer.fit_transform(preprocessed_errors)
        sim_matrix = cosine_similarity(tf_idf_matrix)
        self.tfidf_similarity_matrix = sim_matrix

    def cluster_errors(self, eps=0.5, min_samples=5):
        dbscan = DBSCAN(metric='precomputed', eps=eps, min_samples=min_samples)
        similarity_matrices = {
            'wmd': self.wmd_similarity_matrix,
            'levenshtein': self.levenshtein_similarity_matrix,
            'jaccard': self.jaccard_similarity_matrix,
            'tfidf': self.tfidf_similarity_matrix,
        }
        for matrix_name, matrix in similarity_matrices.items():
            new_col_name = f"{matrix_name}_cluster_id"
            labels = dbscan.fit_predict(matrix)
            self[new_col_name] = labels
