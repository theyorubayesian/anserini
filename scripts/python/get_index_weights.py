import argparse

from pyserini.index.lucene import IndexReader

parser = argparse.ArgumentParser()
parser.add_argument('--index', type=str, required=True)
parser.add_argument('--dump', type=str, required=True)
parser.add_argument('--quantized', type=str, required=True)
args = parser.parse_args()

index_reader = IndexReader(args.index)
dump_file_path = args.dump
quantized_file_path = args.quantized
index_reader.dump_documents_BM25(dump_file_path)
index_reader.quantize_weights(dump_file_path, quantized_file_path)
