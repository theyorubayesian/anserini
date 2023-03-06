# LANG_CODES=("fi" "id" "ja" "ko" "ru" "sw" "te" "th")
# LANGS=("finnish"  "indonesian" "japanese" "korean" "russian" "swahili" "telugu" "thai")
{
    # LANG_CODES=("es" "fa" "hi")
    # LANGS=("spanish" "persian" "hindi")
    LANG_CODES=("yo")
    LANGS=("yoruba")

    DATA_DIR="/tuna1/scratch/aooladip/collections/miracl-cc"
    MIN_TOKENS=6
    SEED=42
    SAMPLE=false
    N_SENTS=(234898927 758437967 234313217 695146828 91430713)
    N_TRAIN_SENTENCES=(10000000 10000000 10000000 10000000 10000000)
    N_EVAL_SENTENCES=(0 0 0 0 0)

    mkdir -p $DATA_DIR

    for i in "${!LANG_CODES[@]}"
        do
            lang=${LANG_CODES[i]}
            wget "http://data.statmt.org/cc-100/$lang.txt.xz" \
            -O "$DATA_DIR/$lang.txt.xz" \
            -o "$DATA_DIR/$lang.txt.xz.out"
            
            unxz "$DATA_DIR/$lang.txt.xz"

            # Remove lines containing only white space or few number of tokens
            cat "$DATA_DIR/$lang.txt" | sed '/^[[:space:]]*$/d' | awk -v n_tokens=$MIN_TOKENS 'NF>n_tokens'> "$DATA_DIR/$lang.new.txt"
            mv "$DATA_DIR/$lang.new.txt" "$DATA_DIR/$lang.txt"

            echo "Downloaded, unzipped & cleaned data for language: $lang"
            tail -n 3 "$DATA_DIR/$lang.txt.xz.out"
            n_sent=$(echo $(wc -l $DATA_DIR/$lang.txt) | cut -d ' ' -f 1) 
            echo "$n_sent sentences in cleaned data"
        
            if [ "$SAMPLE" == true ] ; then
                echo "Sampling sentences from $lang.txt"
                n_sent=${N_SENTS[i]}

                python sample_cc.py \
                --data-dir $DATA_DIR \
                --seed $SEED \
                --filename $lang.txt \
                --n-lines $n_sent \
                --n-lines-train ${N_TRAIN_SENTENCES[$i]} \
                --n-lines-eval ${N_EVAL_SENTENCES[$i]}
            fi
        done
}
