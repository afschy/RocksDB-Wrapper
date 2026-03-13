#!/bin/bash

# Ensure Bash 4+ for associative arrays
if [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
    echo "Error: This script requires Bash 4.0 or higher."
    exit 1
fi

declare -A reset_matrix gc_matrix ops_matrix time_matrix progress_matrix
declare -A all_policies all_rows

# --- Phase 1: Data Collection ---

for d_top in rsvz-*/; do
    [[ -d "$d_top" ]] || continue
    d_top=${d_top%/} 
    
    # Extract x and y (e.g., from rsvz-no_gcstart-10_gcstop-20_...)
    x=$(echo "$d_top" | sed -n 's/.*gcstart-\([^_]*\).*/\1/p')
    y=$(echo "$d_top" | sed -n 's/.*gcstop-\([^_]*\).*/\1/p')
    
    row_label="${x}->${y}"
    all_rows["$row_label"]=1

    for d_fp in "$d_top"/fp-*/; do
        [[ -d "$d_fp" ]] || continue
        d_fp=${d_fp%/}
        policy=${d_fp##*/fp-}
        all_policies["$policy"]=1

        # Locate the latest files
        LATEST_NAME_LOG=$(ls "$d_fp/${policy}"_*.log 2>/dev/null | sort | tail -n 1)
        LATEST_STDOUT_LOG=$(ls "$d_fp/stdout_"*.log 2>/dev/null | sort | tail -n 1)

        # 1. Extraction from name log (Resets, GC)
        if [[ -f "$LATEST_NAME_LOG" ]]; then
            reset_matrix["$row_label,$policy"]=$(grep "Reset count =" "$LATEST_NAME_LOG" | tail -n 1 | sed -n 's/.*Reset count = \([0-9]*\).*/\1/p')
            
            gc_mb=$(grep "Total movement due to GC =" "$LATEST_NAME_LOG" | tail -n 1 | sed -n 's/.*Total movement due to GC = \([0-9.]*\).*/\1/p')
            gc_matrix["$row_label,$policy"]=$(awk -v mb="$gc_mb" 'BEGIN { if (mb == "" || mb == "0") print "0.00"; else printf "%.2f", mb / 1024 }')
        fi

        # 2. Extraction from stdout log (Ops, Time, Progress)
        if [[ -f "$LATEST_STDOUT_LOG" ]]; then
            
            # Extract Ops
            ops_matrix["$row_label,$policy"]=$(grep -E "finished [0-9]+ ops" "$LATEST_STDOUT_LOG" | tail -n 1 | awk '{print $(NF-1)}')

            # Extract Time (Converted to total seconds)
            val_time=$(grep "Experiment completed in" "$LATEST_STDOUT_LOG" | tail -n 1 | awk '{
                sub(/h/, "", $4);
                sub(/m/, "", $5);
                sub(/s/, "", $6);
                print ($4 * 3600) + ($5 * 60) + $6
            }')
            [[ -n "$val_time" ]] && time_matrix["$row_label,$policy"]="$val_time"

            # Extract Max Progress
            val_progress=$(grep -o '[0-9.]\+%' "$LATEST_STDOUT_LOG" | tr -d '%' | sort -n | tail -n 1)
            [[ -n "$val_progress" ]] && progress_matrix["$row_label,$policy"]=$(printf "%.2f" "$val_progress")
            
        fi
    done
done

# --- Phase 2: Row Sorting ---

sorted_rows=$(for r in "${!all_rows[@]}"; do
    curr_x="${r%->*}"
    curr_y="${r#*->}"
    [[ "$curr_y" == "no" ]] && echo "2 $curr_x 0 $r" || echo "1 $curr_x $curr_y $r"
done | sort -k1,1n -k2,2n -k3,3n | awk '{print $NF}')

sorted_policies=$(echo "${!all_policies[@]}" | tr ' ' '\n' | sort)

# --- Phase 3: Writing Matrix Files ---

for type in reset_count gc_movement ops_count time progress; do
    file="${type}.csv"
    header="label"
    for p in $sorted_policies; do header="${header},${p}"; done
    echo "$header" > "$file"

    for r in $sorted_rows; do
        row_str="$r"
        for p in $sorted_policies; do
            case $type in
                reset_count) val=${reset_matrix["$r,$p"]} ;;
                gc_movement) val=${gc_matrix["$r,$p"]} ;;
                ops_count)   val=${ops_matrix["$r,$p"]} ;;
                time)        val=${time_matrix["$r,$p"]} ;;
                progress)    val=${progress_matrix["$r,$p"]} ;;
            esac
            row_str="${row_str},${val}"
        done
        echo "$row_str" >> "$file"
    done
done

echo "Extraction complete. Generated: reset_count.csv, gc_movement.csv, ops_count.csv, time.csv, progress.csv"