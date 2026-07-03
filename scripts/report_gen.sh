#!/bin/bash

# Ensure Bash 4+ for associative arrays
if [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
    echo "Error: This script requires Bash 4.0 or higher."
    exit 1
fi

declare -A reset_matrix gc_matrix time_matrix
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

        # 1. Average reset count and GC movement across all name log timestamps
        name_logs=("$d_fp/${policy}"_*.log)
        if [[ -f "${name_logs[0]}" ]]; then
            reset_matrix["$row_label,$policy"]=$(
                for f in "${name_logs[@]}"; do
                    grep "total_reset =" "$f" | tail -n 1 | sed -n 's/.*total_reset = \([0-9]*\).*/\1/p'
                done | awk 'NF { sum += $1; count++ } END { if (count > 0) printf "%d", sum/count }'
            )
            gc_matrix["$row_label,$policy"]=$(
                for f in "${name_logs[@]}"; do
                    grep "Total movement due to GC =" "$f" | tail -n 1 | sed -n 's/.*Total movement due to GC = \([0-9.]*\).*/\1/p'
                done | awk 'NF { sum += $1; count++ } END { if (count > 0) printf "%.2f", sum/count/1024; else print "0.00" }'
            )
        fi

        # 2. Average execution time across all workload/stdout log timestamps
        val_time=""
        workload_logs=("$d_fp/workload_"*.log)
        if [[ -f "${workload_logs[0]}" ]]; then
            val_time=$(
                for f in "${workload_logs[@]}"; do
                    grep "Workload Execution Time:" "$f" | tail -n 1 | awk '{ printf "%.0f\n", $NF / 1000000000 }'
                done | awk 'NF { sum += $1; count++ } END { if (count > 0) printf "%.0f", sum/count }'
            )
        else
            stdout_logs=("$d_fp/stdout_"*.log)
            if [[ -f "${stdout_logs[0]}" ]]; then
                val_time=$(
                    for f in "${stdout_logs[@]}"; do
                        grep "Uptime(secs):" "$f" | tail -n 1 | awk '{ printf "%.0f\n", $2 + $4 }'
                    done | awk 'NF { sum += $1; count++ } END { if (count > 0) printf "%.0f", sum/count }'
                )
            fi
        fi
        [[ -n "$val_time" ]] && time_matrix["$row_label,$policy"]="$val_time"

    done
done

# --- Phase 2: Row and Policy Sorting ---

sorted_rows=$(for r in "${!all_rows[@]}"; do
    curr_x="${r%->*}"
    curr_y="${r#*->}"
    [[ "$curr_y" == "no" ]] && echo "2 $curr_x 0 $r" || echo "1 $curr_x $curr_y $r"
done | sort -k1,1n -k2,2n -k3,3n | awk '{print $NF}')

# Enforce exact column order for policies
target_order=(default caza oaza zonekv our-oaza overlap)
sorted_policies=""

for p in "${target_order[@]}"; do
    # Only append the policy if it was actually found in the directories
    if [[ -n "${all_policies[$p]}" ]]; then
        sorted_policies="$sorted_policies $p"
    fi
done

# plaza* policies go at the end, in alphabetical order
plaza_policies=$(for p in "${!all_policies[@]}"; do [[ "$p" == plaza* ]] && echo "$p"; done | sort)
for p in $plaza_policies; do
    sorted_policies="$sorted_policies $p"
done

# hybrid* policies go after plaza*, in alphabetical order
hybrid_policies=$(for p in "${!all_policies[@]}"; do [[ "$p" == hybrid* ]] && echo "$p"; done | sort)
for p in $hybrid_policies; do
    sorted_policies="$sorted_policies $p"
done

# Strip leading space
sorted_policies="${sorted_policies# }"

# --- Phase 3: Writing Matrix Files ---

for type in reset_count gc_movement time; do
    file="${type}.csv"
    header="${type}"
    for p in $sorted_policies; do header="${header},${p}"; done
    echo "$header" > "$file"

    for r in $sorted_rows; do
        row_str="$r"
        for p in $sorted_policies; do
            case $type in
                reset_count) val=${reset_matrix["$r,$p"]} ;;
                gc_movement) val=${gc_matrix["$r,$p"]} ;;
                time)        val=${time_matrix["$r,$p"]} ;;
            esac
            row_str="${row_str},${val}"
        done
        echo "$row_str" >> "$file"
    done
done

{ cat gc_movement.csv; echo; echo; cat time.csv; echo; echo; cat reset_count.csv; } > report.csv
rm gc_movement.csv time.csv reset_count.csv
echo "Extraction complete. Generated: report.csv"