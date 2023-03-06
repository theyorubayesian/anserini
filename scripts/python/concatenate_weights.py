import argparse
import os
import json

parser = argparse.ArgumentParser()
parser.add_argument('--bm25', type=str, required=True)
parser.add_argument('--bm25wp', type=str, required=True)
parser.add_argument('--bm50', type=str, required=True)
args = parser.parse_args()

all_bm25_vectors = {}
all_bm25wp_vectors = {}
all_bm50_vectors = {}
max_bm25_weight = 0
max_bm25wp_weight = 0

bm25_path = args.bm25

with open(bm25_path) as f:
    for line in f:
        info = json.loads(line)
        bm25_renamed_vector = {}
        for key in info['vector']:
            bm25_renamed_vector[f'bm25_{key}'] = info['vector'][key]
            if info['vector'][key] > max_bm25_weight:
                max_bm25_weight = info['vector'][key]
        all_bm25_vectors[info['id']] = bm25_renamed_vector

bm25wp_path = args.bm25wp
with open(bm25wp_path) as f:
    for line in f:
        info = json.loads(line)
        bm25wp_renamed_vector = {}
        for key in info['vector']:
            # We ignore keys already in Lucene Analyzed Index
            if f'bm25_{key}' in bm25_renamed_vector:
                continue
            bm25wp_renamed_vector[f'bm25wp_{key}'] = info['vector'][key]
            if info['vector'][key] > max_bm25wp_weight:
                max_bm25wp_weight = info['vector'][key]
        all_bm25wp_vectors[info['id']] = bm25wp_renamed_vector

for key in all_bm25_vectors:
    all_bm50_vectors[key] = {}
    for tok in all_bm25_vectors[key]:
        all_bm50_vectors[key][tok] = all_bm25_vectors[key][tok]
    for tok in all_bm25wp_vectors[key]:
        all_bm50_vectors[key][tok] = all_bm25wp_vectors[key][tok]


with open(args.bm50, 'w') as f:
    for key in all_bm50_vectors:
        f.write(json.dumps({
            'id': key,
            'contents': "",
            'vector': all_bm50_vectors[key]
        })+'\n')

print(max_bm25_weight)
print(max_bm25wp_weight)