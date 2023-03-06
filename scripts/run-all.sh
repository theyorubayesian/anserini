{   
    DEBUG=false
    if [[ $DEBUG == "true" ]]; then set -x; fi

    PREFIX='mrtydi-v1.1-'
    TOKENIZER_DIR='wiki-tokenizers'
    # DATA_DIR="/store/collections/mr-tydi-cc"
    LANG_CODES=("ar" "bn" "fi" "id" "ja" "ko" "ru" "sw" "te" "th")
    LANGS=("arabic" "bengali" "finnish"  "indonesian" "japanese" "korean" "russian" "swahili" "telugu" "thai")
    DATA_DIR=
    
    # VOCAB_SIZES FROM CC TOKENIZER SEARCH
    # VOCAB_SIZES=(30000 10000 20000 50000 20000 50000 50000 10000 80000 30000)

    # VOCAB_SIZES FROM WIKIPEDIA TOKENIZER SEARCH
    VOCAB_SIZES=(20000 30000 20000 40000 20000 50000 20000 10000 80000 10000)

    # TOKENIZER_NAMES=("bert-base-multilingual-uncased")
    # TOKENIZER_NAMES=()
    BATCH_SIZE=1000
    SPLITS=("test")

    # Uncomment to use CustomTokenizer.
    USE_CUSTOM_TOKENIZER=true
    echo "${USE_CUSTOM_TOKENIZER+"Using Custom Tokenizer"}"

    # Uncomment to use CustomTokenizer.
    USE_COMPOSITE_ANALYZER=true    
    echo "${USE_COMPOSITE_ANALYZER+"Using Composite Analyzer"}"

    # Tasks to perform using this script: tokenizer, index, search, eval
    # TASKS=("index" "search" "eval")
    TASKS=("eval")

    # set -n; # No execution. Error checking alone. Uncomment to run.

    # function create_save_path() {
    #     name=$1
    #     return ${name/'/'/'-'}
    # }

    # for VOCAB_SIZE in ${VOCAB_SIZES[@]}
    # do
    for i in ${!LANGS[@]}
    do
        lang=${LANGS[i]}
        lang_code=${LANG_CODES[i]}

        # Set default tokenizer to use 
        if [[ -z $USE_CUSTOM_TOKENIZER ]]; then
            echo "Using bert-base-multilingual-uncased model"
            tokenizer_name="bert-base-multilingual-uncased"
            save_path_prefix="$lang/${USE_COMPOSITE_ANALYZER+"CompAnalyzer/"}bert-base-multilingual-uncased"
        else
            echo "Using custom tokenizers"
            VOCAB_SIZE=${VOCAB_SIZES[i]}
            tokenizer_name="$TOKENIZER_DIR/$lang/v$VOCAB_SIZE-wiki/tokenizer.json"
            save_path_prefix="$lang/${USE_COMPOSITE_ANALYZER+"CompAnalyzer/"}v$VOCAB_SIZE-wiki"
        fi

        if [[ ${TASKS[*]} =~ (^|[[:space:]])"tokenizer"($|[[:space:]]) ]]; then
            # Train Masked Language Model
            echo "Training tokenizer for language: $lang, with vocabulary size: $VOCAB_SIZE"
            logfile="logs/$save_path_prefix/$lang.tokenize.log"
            mkdir -p "$(dirname $logfile)" && touch $logfile

            python scripts/python/train_wordpiece.py \
            --data-path $DATA_DIR/$lang_code.txt \
            --save-path $TOKENIZER_DIR/$save_path_prefix \
            --lowercase \
            --vocab-size $VOCAB_SIZE \
            --batch-size $BATCH_SIZE \
            >& $logfile && \
            echo "Trained and saved tokenizer for $lang" || \
            { echo "Error training tokenizer for $lang" && break; }
        fi

        if [[ ${TASKS[*]} =~ (^|[[:space:]])"index"($|[[:space:]]) ]]; then
            # Train Masked Language Model

            logfile="logs/mr-tydi/$save_path_prefix/$lang.index.log"
            mkdir -p "$(dirname $logfile)" && touch $logfile

            index_dir="/store/scratch/aooladip/indexes/mr-tydi-corpus/$save_path_prefix"
            mkdir -p $index_dir
            echo "Indexing language: $lang with tokenizer: $tokenizer_name"

            target/appassembler/bin/IndexCollection \
            -collection "MrTyDiCollection" \
            -input "/store/collections/mr-tydi-corpus/$PREFIX$lang" \
            -index $index_dir -language $lang_code \
            -generator "DefaultLuceneDocumentGenerator" \
            -threads 32 -storePositions -storeDocvectors -storeRaw \
            -analyzeWithHuggingFaceTokenizer  "$tokenizer_name" \
            ${USE_COMPOSITE_ANALYZER+"-useCompositeAnalyzer"} \
            >& $logfile && \
            echo "Indexed mr-tydi-corpus for $lang with tokenizer: $tokenizer_name" || \
            { echo "Error indexing mr-tydi-corpus for $lang" && rm -r $index_dir && continue; }
        fi

        if [[ ${TASKS[*]} =~ (^|[[:space:]])"search"($|[[:space:]]) ]]; then
            # Train Masked Language Model
            echo "Searching topics for language: $lang"
            for split in ${SPLITS[@]}
            do
                logfile="logs/mr-tydi/$save_path_prefix/search.$split.log"
                output_file="runs/mr-tydi-corpus/$save_path_prefix/$split.txt"

                touch $logfile
                mkdir -p "$(dirname $output_file)" && touch $output_file
                echo "Searching topics for language: $lang, split: $split. Output file: $output_file"

                target/appassembler/bin/SearchCollection \
                -index $index_dir \
                -topics "/store/collections/mr-tydi/$PREFIX$lang/ir-format-data/topics.$split.txt" \
                -language $lang_code \
                -topicreader "TsvInt" \
                -output $output_file \
                -bm25  -analyzeWithHuggingFaceTokenizer "$tokenizer_name" \
                ${USE_COMPOSITE_ANALYZER+"-useCompositeAnalyzer"} \
                >& $logfile && \
                echo "Searched $split topics for $lang with tokenizer: $tokenizer_name. Output file: $output_file" || \
                { echo "Error searching $split topics for $lang with tokenizer: $tokenizer_name. See $logfile" && continue; }
            done
        fi

        if [[ ${TASKS[*]} =~ (^|[[:space:]])"eval"($|[[:space:]]) ]]; then
            # Train Masked Language Model
            for split in ${SPLITS[@]}
            do
                qrel_file="/store/collections/mr-tydi/$PREFIX$lang/ir-format-data/qrels.$split.txt"
                output_file="runs/mr-tydi-corpus/$save_path_prefix/$split.txt" 
                eval_file="runs/mr-tydi-corpus/$save_path_prefix/$split-results.txt"
                
                tools/eval/trec_eval.9.0.4/trec_eval -c -m map $qrel_file $output_file >> $eval_file 
                tools/eval/trec_eval.9.0.4/trec_eval -c -M 10 -m recip_rank $qrel_file $output_file >> $eval_file
                tools/eval/trec_eval.9.0.4/trec_eval -c -m recall.100 $qrel_file $output_file >> $eval_file
                tail -n 2 $eval_file && printf "\n"
                tools/eval/trec_eval.9.0.4/trec_eval -c -m recall.1000 $qrel_file $output_file >> $eval_file && \
                rm -rf $index_dir
            done
        fi
    done

    exit
}