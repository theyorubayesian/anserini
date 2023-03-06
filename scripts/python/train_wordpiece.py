from argparse import ArgumentParser
from argparse import Namespace
from itertools import islice
from typing import Tuple

from tokenizers import (
    decoders,
    models,
    normalizers,
    pre_tokenizers,
    processors,
    trainers,
    Tokenizer
)
from transformers import BertTokenizerFast

SPECIAL_TOKENS = ["[PAD]", "[CLS]", "[SEP]", "[MASK]"]


def setup_args() -> Namespace:
    parser = ArgumentParser()
    parser.add_argument("--data-path")
    parser.add_argument("--save-path")
    parser.add_argument("--tokenizer-name", default="bert-base-multilingual-uncased")
    parser.add_argument("--batch-size", type=int, default=1000)
    parser.add_argument("--unk-token", default="[UNK]")
    parser.add_argument("--lowercase", action="store_true")
    parser.add_argument("--vocab-size", type=int, default=25000)
    parser.add_argument("--decoder-prefix", default="##")
    parser.add_argument("--push-to-hub", action="store_true")
    args = parser.parse_args()
    return args


def batch_iterator(batch_size: int, data_path: str) -> Tuple[str]:
    with open(data_path, "r") as f:
        for lines in iter(lambda: tuple(islice(f, batch_size)), ()):
            yield lines


def main():
    args = setup_args()

    tokenizer = BertTokenizerFast.from_pretrained(args.tokenizer_name)
    
    new_tokenizer = tokenizer.train_new_from_iterator(batch_iterator(args.batch_size, args.data_path), vocab_size=args.vocab_size)
    new_tokenizer.save_pretrained(save_directory=args.save_path, push_to_hub=args.push_to_hub)


if __name__ == "__main__":
    main()
