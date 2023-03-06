{   
    DEBUG=false
    if [[ $DEBUG == "true" ]]; then set -x; fi

    PREFIX='miracl-corpus-v1.0-'
    TOKENIZER_DIR='tokenizers'
    MIRACL_DEV_LINK="https://raw.githubusercontent.com/castorini/anserini/master/src/main/resources/topics-and-qrels/qrels.miracl-v1.0-"
    DATA_DIR="/tuna1/scratch/aooladip/collections/miracl-cc"

    LANG_CODES=("hi" "es" "fa")
    LANGS=("hindi" "spanish" "persian")
    # LANG_CODES=("yo")
    # LANGS=("yoruba")
    # LANG_CODES=("ar" "bn" "fi" "id" "ja" "ko" "ru" "sw" "te" "th")
    # LANGS=("arabic" "bengali" "finnish"  "indonesian" "japanese" "korean" "russian" "swahili" "telugu" "thai")

    # VOCAB_SIZES FROM CC TOKENIZER SEARCH
    # VOCAB_SIZES=(30000 10000 20000 50000 20000 50000 50000 10000 80000 30000)
    VOCAB_SIZES=(20000 30000 30000)
    # VOCAB_SIZES=(20000)

    # VOCAB_SIZES FROM WIKIPEDIA TOKENIZER SEARCH
    # VOCAB_SIZES=(20000 30000 20000 40000 20000 50000 20000 10000 80000 10000)

    # VOCAB SIZES FOR TOKENIZER SEARCH
    # Only one of the following two lins should be uncommented at a time. 
    # VOCAB_SEARCH_SPACE=(10000 20000 30000 40000 50000 60000 70000 80000 100000)   # Perform tokenizer search
    VOCAB_SEARCH_SPACE=${VOCAB_SEARCH_SPACE:-("PLACEHOLDER")}                       # Don't perform tokenizer search
    
    # Uncomment to use HuggingFaceTokenizerAnalyzer
    USE_HF_TOKENIZER_ANALYZER=true
    echo "${USE_HF_TOKENIZER_ANALYZER+"Using HuggingFaceTokenizerAnalyzer"}"
    
    # Uncomment to use CustomTokenizer.
    USE_CUSTOM_TOKENIZER=true
    echo "${USE_CUSTOM_TOKENIZER+"Using Custom Tokenizer"}"

    # Uncomment to use CompositeAnalyzer.
    USE_COMPOSITE_ANALYZER=true
    echo "${USE_COMPOSITE_ANALYZER+"Using Composite Analyzer"}"

    # Uncomment to perform ablation
    # PERFORM_ABLATION=true
    echo "${PERFORM_ABLATION+"Performing ablation. Will use WhitespaceAnalyzer for indexing & searching"}"

    BATCH_SIZE=1000
    SPLITS=("dev")

    if [[ -z $USE_HF_TOKENIZER_ANALYZER && ! -z $PERFORM_ABLATION ]]; then
        echo "Using Lucene Analyzer"
    fi

    # Tasks to perform using this script: tokenizer, index, search, eval
    TASKS=("index" "search" "eval")
    # TASKS=("search" "eval")

    # set -n; # No execution. Error checking alone. Uncomment to run.

    for VOCAB_SIZE in ${VOCAB_SEARCH_SPACE[@]}
    do
        for i in ${!LANGS[@]}
        do
            lang=${LANGS[i]}
            lang_code=${LANG_CODES[i]}
            qrel_file="data/qrels.miracl-v1.0-$lang_code-dev.tsv"

            # if [[ ! -s $qrel_file ]]; then
            #     FULL_MIRACL_DEV_LINK="$MIRACL_DEV_LINK$lang_code-dev.tsv"
            #     wget $FULL_MIRACL_DEV_LINK -O $qrel_file
            # fi

            # Set default tokenizer to use 
            if [[ -z $USE_HF_TOKENIZER_ANALYZER ]]; then
                save_path_prefix="${PERFORM_ABLATION+"ablation/"}$lang/LuceneAnalyzer"
            elif [[ -z $USE_CUSTOM_TOKENIZER ]]; then
                echo "Using bert-base-multilingual-uncased model"
                tokenizer_name="bert-base-multilingual-uncased"
                save_path_prefix="${PERFORM_ABLATION+"ablation/"}fullablation/$lang/${USE_COMPOSITE_ANALYZER+"CompAnalyzer/"}bert-base-multilingual-uncased"
            else
                echo "Using custom tokenizers"
                if [[ ${#VOCAB_SEARCH_SPACE[@]} -eq 1 ]]; then
                    # Use Vocab Size corresponding to language
                    VOCAB_SIZE=${VOCAB_SIZES[i]}
                fi

                tokenizer_name="$TOKENIZER_DIR/$lang/v$VOCAB_SIZE/tokenizer.json"
                save_path_prefix="${PERFORM_ABLATION+"ablation/"}fullablation/$lang/${USE_COMPOSITE_ANALYZER+"CompAnalyzer/"}v$VOCAB_SIZE"
            fi

            index_dir="/tuna1/scratch/aooladip/indexes/miracl-corpus/$save_path_prefix"
            mkdir -p $index_dir

            if [[ ${TASKS[*]} =~ (^|[[:space:]])"tokenizer"($|[[:space:]]) ]]; then
                # Train tokenizer
                echo "Training tokenizer for language: $lang, with vocabulary size: $VOCAB_SIZE"
                mkdir -p $TOKENIZER_DIR/$save_path_prefix

                logfile="logs/miracl/$save_path_prefix/$lang.tokenize.log"
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
                # Index corpus

                logfile="logs/miracl/$save_path_prefix/$lang.index.log"
                mkdir -p "$(dirname $logfile)" && touch $logfile

                # echo "Indexing language: $lang ${USE_HF_TOKENIZER_ANALYZER+"with tokenizer: $tokenizer_name"}"

                target/appassembler/bin/IndexCollection \
                -collection "MrTyDiCollection" \
                -input "/tuna1/scratch/aooladip/collections/miracl-corpus/$PREFIX$lang_code" \
                -index $index_dir \
                -language $lang_code \
                ${PERFORM_ABLATION+"-language" "sw"} \
                -generator "DefaultLuceneDocumentGenerator" \
                -threads 32 \
                ${USE_HF_TOKENIZER_ANALYZER+"-analyzeWithHuggingFaceTokenizer" "$tokenizer_name"} \
                ${USE_COMPOSITE_ANALYZER+"-useCompositeAnalyzer"} \
                >& $logfile && \
                echo "Indexed mr-tydi-corpus for $lang with tokenizer: $tokenizer_name" || \
                { echo "Error indexing mr-tydi-corpus for $lang" && rm -r $index_dir && continue; }
            fi

            if [[ ${TASKS[*]} =~ (^|[[:space:]])"search"($|[[:space:]]) ]]; then
                # Search index for topics
                echo "Searching topics for language: $lang"
                for split in ${SPLITS[@]}
                do
                    logfile="logs/miracl/$save_path_prefix/search.$split.log"
                    output_file="runs/miracl-corpus/$save_path_prefix/$split.txt"

                    touch $logfile
                    mkdir -p "$(dirname $output_file)" && touch $output_file
                    echo "Searching topics for language: $lang, split: $split. Output file: $output_file"

                    target/appassembler/bin/SearchCollection \
                    -index $index_dir \
                    -topics "/tuna1/scratch/aooladip/collections/miracl/miracl-v1.0-$lang_code/topics/topics.miracl-v1.0-$lang_code-$split.tsv" \
                    -language $lang_code \
                    ${PERFORM_ABLATION+"-language" "sw"} \
                    -topicreader "TsvString" \
                    -output $output_file \
                    -bm25 \
                    ${USE_HF_TOKENIZER_ANALYZER+"-analyzeWithHuggingFaceTokenizer" "$tokenizer_name"} \
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
                    output_file="runs/miracl-corpus/$save_path_prefix/$split.txt" 
                    eval_file="runs/miracl-corpus/$save_path_prefix/$split-results.txt"
                    qrel_file="/tuna1/scratch/aooladip/collections/miracl/miracl-v1.0-$lang_code/qrels/qrels.miracl-v1.0-$lang_code-$split.tsv"
                    
                    tools/eval/trec_eval.9.0.4/trec_eval -c -m map $qrel_file $output_file >> $eval_file 
                    tools/eval/trec_eval.9.0.4/trec_eval -c -M 10 -m recip_rank $qrel_file $output_file >> $eval_file
                    tools/eval/trec_eval.9.0.4/trec_eval -c -m recall.100 $qrel_file $output_file >> $eval_file
                    tools/eval/trec_eval.9.0.4/trec_eval -c -m ndcg_cut.10 $qrel_file $output_file >> $eval_file
                    tail -n 3 $eval_file && printf "\n"
                    tools/eval/trec_eval.9.0.4/trec_eval -c -m recall.1000 $qrel_file $output_file >> $eval_file && \
                    rm -rf $index_dir
                done
            fi
        done
    done

    exit
}