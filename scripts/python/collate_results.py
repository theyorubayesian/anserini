import json
from collections import defaultdict
from glob import glob
from pathlib import Path

runs_dir = Path("runs/miracl-corpus")

# Tweak this
fname = "dev-results.txt"
result_files = sorted(glob(str(runs_dir) + f"/**/CompAnalyzer/bert*/{fname}"))
output_file = "runs/tokenizer_search/wikipedia-miracl-hindi-persian-spanish-tokenizers.json"
langs_of_interest = ["hindi", "persian", "spanish"]

DEBUG = True
RETURN_DICT = False
USES_COMPOSITE_ANALYZER = True
IS_ABLATION = False
if DEBUG:
    print(result_files)

LANGS = []
MRR_LIST = []
R100_LIST = []
NDCG10_LIST = []
VOCAB_SIZES = []

results = defaultdict(dict)

for result in result_files:
    if not any([x in result for x in langs_of_interest]):
        continue
    
    VOCAB_SIZE = Path(result).parents[0].name
    LANG = Path(result).parents[int(USES_COMPOSITE_ANALYZER)+1].name 

    result = runs_dir / "ablation" / LANG if IS_ABLATION else runs_dir / LANG

    if USES_COMPOSITE_ANALYZER:
        result = result / "CompAnalyzer"
    
    result = result / VOCAB_SIZE / fname

    if DEBUG:
        print(result)
        print(VOCAB_SIZE)
        print(LANG)
        exit()

    metrics = list(filter(None, Path(result).read_text().split("\n")))

    if not metrics:
        continue

    MRR = "{:.3f}".format(float(metrics[1].split("\t")[-1]))
    R100 = "{:.3f}".format(float(metrics[2].split("\t")[-1]))
    NDCG10 = "{:.3f}".format(float(metrics[3].split("\t")[-1]))

    LANGS.append(LANG)
    MRR_LIST.append(MRR)
    R100_LIST.append(R100)
    NDCG10_LIST.append(NDCG10)

    VOCAB_SIZES.append(VOCAB_SIZE[1:])

    if RETURN_DICT:
        results[LANG][VOCAB_SIZE] = [MRR, R100]

# print(LANGS[::-1])
# print(" & ".join(MRR_LIST[::-1]))
# print(" & ".join(R100_LIST[::-1]))
# print(" & ".join(NDCG10_LIST[::-1]))
# print(" & ".join(VOCAB_SIZES[::-1]))
print(LANGS)
print(" & ".join(NDCG10_LIST))
print(" & ".join(MRR_LIST))
print(" & ".join(R100_LIST))
print(" & ".join(VOCAB_SIZES))


if RETURN_DICT:
    json.dump(dict(results), open(output_file, "w"), indent=4)
