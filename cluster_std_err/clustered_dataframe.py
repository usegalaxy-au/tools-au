#!/usr/bin/env python3

from nltk import word_tokenize, download
from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer
from sklearn.cluster import DBSCAN
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import Levenshtein
import numpy as np
import pandas as pd


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
        self.compute_levenshtein_similarity()
        self.compute_jaccard_similarity()
        self.compute_tfidf_similarity()

        # Add the cluster IDs
        self.cluster_errors()

    def tokenize_err(self):
        # Download stopwords and WordNet lemmatizer if necessary
        download('stopwords')
        download('wordnet')
        download('punkt')
        stop_words = set(stopwords.words('english'))
        lemmatizer = WordNetLemmatizer()

        # Pre-process error messages
        preprocessed_errors = []
        for error in self.error_messages:
            print(error)
            # Tokenize
            tokens = word_tokenize(error.lower())

            # Remove stop words and non-alphabetic characters, and lemmatize
            filtered_tokens = [lemmatizer.lemmatize(t)
                               for t in tokens
                               if t.isalpha() and t not in stop_words]

            preprocessed_errors.append(' '.join(filtered_tokens))
        self['tokenized_err'] = preprocessed_errors

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
        dbscan = DBSCAN(
            metric='precomputed',
            eps=eps,
            min_samples=min_samples)
        similarity_matrices = {
            'levenshtein': self.levenshtein_similarity_matrix,
            'jaccard': self.jaccard_similarity_matrix,
            'tfidf': self.tfidf_similarity_matrix,
        }
        for matrix_name, matrix in similarity_matrices.items():
            new_col_name = f"{matrix_name}_cluster_id"
            distance_matrix = 1 - matrix
            distance_matrix[distance_matrix < 0] = 0
            labels = dbscan.fit_predict(distance_matrix)
            print(labels)
            self.loc[:, new_col_name] = labels
