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

# --- Phase 3a: Writing CSV Report ---

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

# --- Phase 3b: Writing Markdown Report ---

report="report.md"

# Render one metric as an aligned Markdown table.
# Every cell is padded to its column's max width, so the table stays
# readable as plain text while remaining valid Markdown.
#   $1 = matrix type (reset_count|gc_movement|time)
#   $2 = section title
#   $3 = top-left (corner) header label
print_table() {
    local type="$1" title="$2" corner="$3"
    local p r i

    # Column headers: corner label followed by each policy.
    local -a headers=( "$corner" )
    for p in $sorted_policies; do headers+=( "$p" ); done
    local ncols=${#headers[@]}

    # Track the widest string seen in each column (start from the header).
    local -a widths
    for ((i = 0; i < ncols; i++)); do widths[i]=${#headers[i]}; done

    # Collect the data cells row-major, updating column widths as we go.
    local -a table_cells
    local nrows=0
    for r in $sorted_rows; do
        local -a cells=( "$r" )
        for p in $sorted_policies; do
            local val
            case $type in
                reset_count) val=${reset_matrix["$r,$p"]} ;;
                gc_movement) val=${gc_matrix["$r,$p"]} ;;
                time)        val=${time_matrix["$r,$p"]} ;;
            esac
            [[ -z "$val" ]] && val="-"
            cells+=( "$val" )
        done
        for ((i = 0; i < ncols; i++)); do
            (( ${#cells[i]} > widths[i] )) && widths[i]=${#cells[i]}
            table_cells+=( "${cells[i]}" )
        done
        ((nrows++))
    done

    # Emit the section. Column 0 (labels) is left-aligned; the numeric
    # columns are right-aligned for tidy text-mode reading.
    local line cell dashes
    {
        echo "## $title"
        echo

        # Header row.
        line="|"
        for ((i = 0; i < ncols; i++)); do
            if ((i == 0)); then
                printf -v cell ' %-*s |' "${widths[i]}" "${headers[i]}"
            else
                printf -v cell ' %*s |' "${widths[i]}" "${headers[i]}"
            fi
            line+="$cell"
        done
        echo "$line"

        # Separator row (alignment colons: left for labels, right for numbers).
        line="|"
        for ((i = 0; i < ncols; i++)); do
            printf -v dashes '%*s' "${widths[i]}" ''
            dashes=${dashes// /-}
            if ((i == 0)); then
                line+=" :${dashes:1} |"
            else
                line+=" ${dashes:1}: |"
            fi
        done
        echo "$line"

        # Data rows.
        local row col idx
        for ((row = 0; row < nrows; row++)); do
            line="|"
            for ((col = 0; col < ncols; col++)); do
                idx=$((row * ncols + col))
                if ((col == 0)); then
                    printf -v cell ' %-*s |' "${widths[col]}" "${table_cells[idx]}"
                else
                    printf -v cell ' %*s |' "${widths[col]}" "${table_cells[idx]}"
                fi
                line+="$cell"
            done
            echo "$line"
        done

        echo
    } >> "$report"
}

{
    echo "# Benchmark Report"
    echo
} > "$report"

print_table gc_movement "GC Movement"     "gc_movement"
print_table time        "Execution Time"  "time"
print_table reset_count "Reset Count"     "reset_count"

echo "Extraction complete. Generated: report.csv and $report"