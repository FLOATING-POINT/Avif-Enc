#!/usr/bin/env bash
# avifenc-bash-jpg-to-avif.sh
# Linux version 
# Features: dry-run, absolute paths, accurate timing, readable output
# Dry run use flags --dry-run or -u 
#
# Make sure Avifenc is installed
#
# ------------------------------------------------------------
# HOW TO RUN 
# ------------------------------------------------------------
# chmod +x avifenc-bash-jpg-to-avif.sh avifenc-bash-jpg-avif.conf
#
# Safe dry-run
# bash avifenc-bash-jpg-to-avif.sh-n
#
# Real conversion
# bash avifenc-bash-jpg-to-avif.sh

set -euo pipefail

# ===== SETTINGS =====
EXT_OUT="avif"
EXT_IN="jpg"
DELETE_ORIG="false"          # Change to "true" only after testing

# Script directory (absolute)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_S="${SCRIPT_DIR}/log-${EXT_IN}-${EXT_OUT}-success.txt"
LOG_F="${SCRIPT_DIR}/log-${EXT_IN}-${EXT_OUT}-failure.txt"

# Config script
CONFIG_SCRIPT="${SCRIPT_DIR}/avifenc-bash-${EXT_IN}-${EXT_OUT}.conf"

# Counters
TOTAL_FILES=0
SUCCESS_FILES=0
FAILED_FILES=0
TOTAL_ORIGINAL_SIZE=0
TOTAL_AVIF_SIZE=0
DRY_RUN=false
PAUSE_EVERY=10

# ===== Parse arguments =====
for arg in "$@"; do
    case "$arg" in
        --dry-run|-n)
            DRY_RUN=true
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run|-n]"
            echo
            echo "  --dry-run, -n    Simulate only. No files are written or deleted."
            echo "  --help, -h       Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            echo "Use --help for usage." >&2
            exit 1
            ;;
    esac
done

# ===== Logging helpers =====
log_all() {
    echo "$*"
    if [[ "$DRY_RUN" == false ]]; then
        echo "$*" >> "$LOG_S"
        echo "$*" >> "$LOG_F"
    fi
}

log_success() {
    echo "$*"
    if [[ "$DRY_RUN" == false ]]; then
        echo "$*" >> "$LOG_S"
    fi
}

log_failure() {
    echo "$*"
    if [[ "$DRY_RUN" == false ]]; then
        echo "$*" >> "$LOG_F"
    fi
}

# Accurate millisecond timer
get_time_ms() {
    echo $(($(date +%s%N)/1000000))
}

# ===== START =====
log_all "========================================="
log_all "Current script: $(basename "$0")"
log_all "Starting at [$(date)]"
log_all "EXT_OUT: $EXT_OUT"
log_all "EXT_IN: $EXT_IN"
log_all "DELETE_ORIG: $DELETE_ORIG"
log_all "Working directory: $(pwd)"

if [[ "$DRY_RUN" == true ]]; then
    log_all ""
    log_all ">>> DRY-RUN MODE ENABLED <<<"
    log_all "No files will be written or deleted."
    log_all "The script will pause every $PAUSE_EVERY files."
    log_all ""
fi

log_all "========================================="
log_all ""

# Find all JPG files recursively
mapfile -d '' -t jpg_files < <(find . -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -print0)

if [[ ${#jpg_files[@]} -eq 0 ]]; then
    log_all "No .jpg / .jpeg files found."
    exit 0
fi

log_all "Found ${#jpg_files[@]} .jpg/.jpeg file(s)."
log_all ""

for input_file in "${jpg_files[@]}"; do
    ((TOTAL_FILES++)) || true

    log_success "*******************************************"
    log_success "[$TOTAL_FILES/${#jpg_files[@]}] Converting ${EXT_IN}: $input_file"
    log_success "[$(date)] Processing: $input_file"

    # Absolute paths
    input_abs="$(realpath "$input_file")"
    input_size=$(stat -c%s "$input_abs" 2>/dev/null || echo 0)

    log_success "Input size       : $input_size bytes"
    log_success "Input (absolute) : $input_abs"

    # Keep original subdirectory structure
    output_file="${input_file%.*}.${EXT_OUT}"
    output_abs="$(realpath -m "$output_file")"

    log_success "Output file      : $output_file"
    log_success "Output (absolute): $output_abs"

    if [[ "$DRY_RUN" == true ]]; then
        log_success ""
        log_success ">>> DRY-RUN: Would convert"
        log_success "    FROM → $input_abs"
        log_success "    TO   → $output_abs"
        log_success ">>> No action taken."
        ((SUCCESS_FILES++)) || true
    else
        # Real conversion
        start_ms=$(get_time_ms)

        if [[ ! -f "$CONFIG_SCRIPT" ]]; then
            log_failure "Config file missing: $CONFIG_SCRIPT"
            log_failure "*******************************************"
            ((FAILED_FILES++)) || true
            continue
        fi

        log_success "Config file found: $(basename "$CONFIG_SCRIPT")"
        log_success "Calling avifenc..."

        set +e
        bash "$CONFIG_SCRIPT" "$input_abs" "$output_abs"
        AVIF_EXIT_CODE=$?
        set -e

        log_success "Exit code: $AVIF_EXIT_CODE"

        end_ms=$(get_time_ms)
        duration_ms=$((end_ms - start_ms))
        if (( duration_ms < 0 )); then
            duration_ms=0
        fi
        duration_sec=$((duration_ms / 1000))
        duration_ms_remainder=$((duration_ms % 1000))
        printf -v duration_fmt "%d.%03d" "$duration_sec" "$duration_ms_remainder"

        if [[ -f "$output_abs" ]]; then
            output_size=$(stat -c%s "$output_abs" 2>/dev/null || echo 0)

            TOTAL_ORIGINAL_SIZE=$((TOTAL_ORIGINAL_SIZE + input_size))
            TOTAL_AVIF_SIZE=$((TOTAL_AVIF_SIZE + output_size))

            if (( input_size > 0 )); then
                REDUCTION=$((100 - output_size * 100 / input_size))
            else
                REDUCTION=0
            fi

            log_success "Output size      : $output_size bytes"
            log_success "Size reduction   : ${REDUCTION}%"
            log_success "SUCCESS: Created $output_abs"
            log_success "Time taken       : ${duration_fmt} seconds"

            ((SUCCESS_FILES++)) || true

            if [[ "$DELETE_ORIG" == "true" ]]; then
                log_success "Deleting original: $input_abs"
                rm -f -- "$input_abs"
            fi
        else
            log_failure "*******************************************"
            log_failure "FAILED: Could not create $output_abs"
            log_failure "Exit code: $AVIF_EXIT_CODE"
            log_failure "Time taken: ${duration_fmt} seconds"
            log_failure "*******************************************"
            ((FAILED_FILES++)) || true
        fi
    fi

    log_success ""

    # Pause in dry-run so output stays readable
    if [[ "$DRY_RUN" == true ]] && (( TOTAL_FILES % PAUSE_EVERY == 0 )); then
        echo
        echo "----- Paused after $TOTAL_FILES files (dry-run) -----"
        echo "Press Enter to continue, or Ctrl+C to stop..."
        read -r
        echo
    fi
done

# ===== SUMMARY =====
log_success ""
log_success "========================================"
if [[ "$DRY_RUN" == true ]]; then
    log_success "DRY-RUN Summary (no files were changed):"
else
    log_success "Conversion Summary:"
fi
log_success "Total files processed : $TOTAL_FILES"
log_success "Successful            : $SUCCESS_FILES"
log_success "Failed                : $FAILED_FILES"

if [[ "$DRY_RUN" == false ]] && (( TOTAL_ORIGINAL_SIZE > 0 )); then
    TOTAL_REDUCTION=$((100 - TOTAL_AVIF_SIZE * 100 / TOTAL_ORIGINAL_SIZE))
    log_success "Total size reduction  : ${TOTAL_REDUCTION}%"
    log_success "Original total size   : $TOTAL_ORIGINAL_SIZE bytes"
    log_success "Converted total size  : $TOTAL_AVIF_SIZE bytes"
fi

log_success ""
log_success "========================================"
log_success "Finished at [$(date)]"
log_success "========================================"

if [[ "$DRY_RUN" == false ]]; then
    echo
    echo "Log files created in: $SCRIPT_DIR"
    echo "Success log : $LOG_S"
    echo "Failure log : $LOG_F"
    echo
fi