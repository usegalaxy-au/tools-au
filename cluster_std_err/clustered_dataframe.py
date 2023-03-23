#!/usr/bin/env python3

from collections import Counter
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
    __slots__ = [
        "_error_messages"
        "_similarity_matrix",
        "_similarity_metric"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
        if 'tool_stderr' not in self.columns:
            raise ValueError(
                "The 'tool_stderr' column is missing from the DataFrame.")

        # create list of error messages for quick access
        setattr(self, "_error_messages", self['tool_stderr'].tolist())

        # tokenise the errors
        self.tokenize_err()

        # run the similarity calculations
        self.compute_similarity_matrix()

        # add the cluster IDs
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
        for error in self._error_messages:
            print(error)
            # Tokenize
            tokens = word_tokenize(error.lower())

            # Remove stop words and non-alphabetic characters, and lemmatize
            filtered_tokens = [lemmatizer.lemmatize(t)
                               for t in tokens
                               if t.isalpha() and t not in stop_words]

            preprocessed_errors.append(' '.join(filtered_tokens))
        self.loc[:, 'tokenized_err'] = preprocessed_errors

    def compute_similarity_matrix(self, method='levenshtein'):
        if method not in ['levenshtein', 'jaccard', 'tfidf']:
            raise ValueError(
                ("Invalid similarity method. Choose "
                 "from 'levenshtein', 'jaccard', or 'tfidf'."))       
        
        preprocessed_errors = self.tokenized_err
        
        # Levenshtein distance
        if method == 'levenshtein':
            sim_matrix = np.zeros(
                (len(preprocessed_errors),
                 len(preprocessed_errors)))
            for i in range(len(preprocessed_errors)):
                for j in range(i, len(preprocessed_errors)):
                    sim_matrix[i, j] = sim_matrix[j, i] = 1 - Levenshtein.distance(
                        preprocessed_errors[i], preprocessed_errors[j]) / max(
                        len(preprocessed_errors[i]), len(preprocessed_errors[j]))

        # Jaccard distance
        if method == "jaccard":
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

        # TF-IDF distance (cosine similarity)
        if method == "tfidf":
            vectorizer = TfidfVectorizer()
            tf_idf_matrix = vectorizer.fit_transform(preprocessed_errors)
            sim_matrix = cosine_similarity(tf_idf_matrix)

        # store the result
        setattr(self, '_similarity_matrix', sim_matrix)
        setattr(self, '_similarity_metric', method)

    def cluster_errors(self, eps=0.5, min_samples=5):
        dbscan = DBSCAN(
            metric='precomputed',
            eps=eps,
            min_samples=min_samples)
        distance_matrix = 1 - self._similarity_matrix 
        distance_matrix[distance_matrix < 0] = 0
        labels = dbscan.fit_predict(distance_matrix)
        self.loc[:, 'cluster_id'] = labels

    def summarize_clusters(self):
        # create an empty dataframe to store the cluster summaries
        summary_df = pd.DataFrame(columns=[
            'cluster_id',
            'num_messages',
            'representative_error'])
        
        # loop over the cluster groups
        for cluster_id in self.cluster_id.unique():
            if cluster_id == -1:
                continue

            cluster_indices = self.index[self.cluster_id == cluster_id]
            num_messages = len(cluster_indices)
            representative_error_index = self._similarity_matrix[cluster_indices, :].sum(axis=0).argmax()
            representative_error = self._error_messages[representative_error_index]

            cluster_summary = pd.DataFrame({
                'cluster_id': [cluster_id],
                'num_messages': [num_messages],
                'representative_error': [representative_error]
            })

            # add the cluster summary to the summary DataFrame
            summary_df = pd.concat(
                [summary_df, cluster_summary],
                ignore_index=True)
        
        return summary_df
