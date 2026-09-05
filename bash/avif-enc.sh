#!/usr/bin/env bash
# avifenc-batch.sh
# Unified batch converter: PNG/JPG → AVIF
# Supports dry-run, format selection, quality/speed control, and custom config files

set -euo pipefail

# ===== Defaults =====
FORMAT_IN=""
FORMAT_OUT="avif"
DELETE_ORIG=false
DRY_RUN=false
QUALITY=92
SPEED=4
CHROMA=""                  # auto-selected later
SEARCH_DIR="."
PAUSE_EVERY=10
CONFIG_FILE=""             # custom config script (optional)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== Help =====
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Required:
  --format-in, --fi FORMAT     Input format: png | jpg | jpeg

Optional:
  --format-out, --fo FORMAT    Output format (currently only avif)     [avif]
  --config, -c FILE            Use a custom config script instead of built-in settings
  --dry-run, -n                Simulate only – no files written/deleted
  --delete-orig, -d            Delete original files after successful conversion
  --quality, -q N              avifenc quality 0-100                   [92]
  --speed, -s N                Encoder speed 0-10 (lower = better)     [4]
  --chroma, -y MODE            420 | 422 | 444                         [auto]
  --dir DIR                    Directory to process                    [.]
  --pause-every N              Pause every N files in dry-run          [10]
  --help, -h                   Show this help

Examples:
  $(basename "$0") --fi png -n
  $(basename "$0") --fi jpg -q 85 -s 6 -d
  $(basename "$0") --fi png --config ./my-avif-config.sh
  $(basename "$0") --fi jpg -c /path/to/avifenc-bat-jpg-avif.conf
EOF
}

# ===== Parse arguments =====
while [[ $# -gt 0 ]]; do
    case "$1" in
        --format-in|--fi)
            FORMAT_IN="${2,,}"
            shift 2
            ;;
        --format-out|--fo)
            FORMAT_OUT="${2,,}"
            shift 2
            ;;
        --config|-c)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --delete-orig|-d)
            DELETE_ORIG=true
            shift
            ;;
        --quality|-q)
            QUALITY="$2"
            shift 2
            ;;
        --speed|-s)
            SPEED="$2"
            shift 2
            ;;
        --chroma|-y)
            CHROMA="$2"
            shift 2
            ;;
        --dir)
            SEARCH_DIR="$2"
            shift 2
            ;;
        --pause-every)
            PAUSE_EVERY="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage." >&2
            exit 1
            ;;
    esac
done

# ===== Validation =====
if [[ -z "$FORMAT_IN" ]]; then
    echo "Error: --format-in / --fi is required (png, jpg, or jpeg)" >&2
    exit 1
fi

case "$FORMAT_IN" in
    png|jpg|jpeg) ;;
    *)
        echo "Error: unsupported input format '$FORMAT_IN'. Use png, jpg or jpeg." >&2
        exit 1
        ;;
esac

if [[ "$FORMAT_OUT" != "avif" ]]; then
    echo "Error: only 'avif' is currently supported as output format." >&2
    exit 1
fi

# ===== Config file validation =====
if [[ -n "$CONFIG_FILE" ]]; then
    # 1. File must exist
    if [[ ! -e "$CONFIG_FILE" ]]; then
        echo "Error: config file does not exist: $CONFIG_FILE" >&2
        exit 1
    fi

    # 2. Must be a regular file
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Error: config path is not a regular file: $CONFIG_FILE" >&2
        exit 1
    fi

    # 3. Must be readable
    if [[ ! -r "$CONFIG_FILE" ]]; then
        echo "Error: config file is not readable: $CONFIG_FILE" >&2
        exit 1
    fi

    # 4. Try to make it executable if it isn't
    if [[ ! -x "$CONFIG_FILE" ]]; then
        echo "Note: config file is not executable – attempting to add +x permission..."
        if chmod +x "$CONFIG_FILE" 2>/dev/null; then
            echo "      Successfully made executable."
        else
            echo "Warning: could not make config file executable. Will try to run with 'bash' anyway."
        fi
    fi

    # 5. Basic content sanity check (optional but useful)
    if ! head -n 1 "$CONFIG_FILE" | grep -qE '^#!.*(bash|sh)'; then
        echo "Warning: config file does not start with a bash/sh shebang."
        echo "         It will still be executed with 'bash', but this may indicate a problem."
    fi

    # Resolve to absolute path for cleaner logging
    CONFIG_FILE="$(realpath "$CONFIG_FILE")"
fi

# Auto-select chroma if not specified and not using custom config
if [[ -z "$CHROMA" && -z "$CONFIG_FILE" ]]; then
    if [[ "$FORMAT_IN" == "png" ]]; then
        CHROMA="444"
    else
        CHROMA="420"
    fi
fi

if [[ -n "$CHROMA" ]]; then
    case "$CHROMA" in
        420|422|444) ;;
        *)
            echo "Error: --chroma must be 420, 422 or 444" >&2
            exit 1
            ;;
    esac
fi

# ===== Logging setup =====
LOG_S="${SCRIPT_DIR}/log-${FORMAT_IN}-${FORMAT_OUT}-success.txt"
LOG_F="${SCRIPT_DIR}/log-${FORMAT_IN}-${FORMAT_OUT}-failure.txt"

TOTAL_FILES=0
SUCCESS_FILES=0
FAILED_FILES=0
TOTAL_ORIGINAL_SIZE=0
TOTAL_OUTPUT_SIZE=0

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

get_time_ms() {
    echo $(($(date +%s%N)/1000000))
}

# ===== Start =====
log_all "========================================="
log_all "avifenc-batch.sh"
log_all "Started at [$(date)]"
log_all "Input format   : $FORMAT_IN"
log_all "Output format  : $FORMAT_OUT"
if [[ -n "$CONFIG_FILE" ]]; then
    log_all "Config file    : $CONFIG_FILE"
else
    log_all "Quality        : $QUALITY"
    log_all "Speed          : $SPEED"
    log_all "Chroma         : $CHROMA"
fi
log_all "Delete original: $DELETE_ORIG"
log_all "Search dir     : $SEARCH_DIR"
log_all "Dry-run        : $DRY_RUN"
log_all "========================================="
log_all ""

# Find files
if [[ "$FORMAT_IN" == "jpg" || "$FORMAT_IN" == "jpeg" ]]; then
    mapfile -d '' -t files < <(find "$SEARCH_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -print0 2>/dev/null)
else
    mapfile -d '' -t files < <(find "$SEARCH_DIR" -type f -iname "*.${FORMAT_IN}" -print0 2>/dev/null)
fi

if [[ ${#files[@]} -eq 0 ]]; then
    log_all "No matching files found in $SEARCH_DIR"
    exit 0
fi

log_all "Found ${#files[@]} file(s) to process."
log_all ""

for input_file in "${files[@]}"; do
    ((TOTAL_FILES++)) || true

    log_success "*******************************************"
    log_success "[$TOTAL_FILES/${#files[@]}] $input_file"

    input_abs="$(realpath "$input_file")"
    input_size=$(stat -c%s "$input_abs" 2>/dev/null || echo 0)

    output_file="${input_file%.*}.${FORMAT_OUT}"
    output_abs="$(realpath -m "$output_file")"

    log_success "Input  : $input_abs ($input_size bytes)"
    log_success "Output : $output_abs"

    if [[ "$DRY_RUN" == true ]]; then
        if [[ -n "$CONFIG_FILE" ]]; then
            log_success ">>> DRY-RUN: would call config → $(basename "$CONFIG_FILE")"
        else
            log_success ">>> DRY-RUN: would convert with quality=$QUALITY speed=$SPEED chroma=$CHROMA"
        fi
        ((SUCCESS_FILES++)) || true
    else
        start_ms=$(get_time_ms)

        set +e
        if [[ -n "$CONFIG_FILE" ]]; then
            # Use custom config script
            bash "$CONFIG_FILE" "$input_abs" "$output_abs"
            EXIT_CODE=$?
        else
            # Built-in avifenc command
            avifenc \
                --ignore-xmp \
                --ignore-exif \
                --ignore-profile \
                --ignore-icc \
                -q "$QUALITY" \
                -s "$SPEED" \
                -y "$CHROMA" \
                -a end-usage=q \
                -a cq-level=36 \
                -a tune=ssim \
                -a color:sharpness=1 \
                -a color:enable-chroma-deltaq=1 \
                -a color:enable-qm=1 \
                -a color:deltaq-mode=3 \
                "$input_abs" "$output_abs"
            EXIT_CODE=$?
        fi
        set -e

        end_ms=$(get_time_ms)
        duration_ms=$((end_ms - start_ms))
        (( duration_ms < 0 )) && duration_ms=0
        duration_sec=$((duration_ms / 1000))
        duration_ms_rem=$((duration_ms % 1000))
        printf -v duration_fmt "%d.%03d" "$duration_sec" "$duration_ms_rem"

        if [[ -f "$output_abs" ]]; then
            output_size=$(stat -c%s "$output_abs" 2>/dev/null || echo 0)
            TOTAL_ORIGINAL_SIZE=$((TOTAL_ORIGINAL_SIZE + input_size))
            TOTAL_OUTPUT_SIZE=$((TOTAL_OUTPUT_SIZE + output_size))

            if (( input_size > 0 )); then
                REDUCTION=$((100 - output_size * 100 / input_size))
            else
                REDUCTION=0
            fi

            log_success "SUCCESS  : $output_size bytes (${REDUCTION}% smaller)"
            log_success "Time     : ${duration_fmt}s"
            ((SUCCESS_FILES++)) || true

            if [[ "$DELETE_ORIG" == true ]]; then
                log_success "Deleting original: $input_abs"
                rm -f -- "$input_abs"
            fi
        else
            log_failure "FAILED   : exit code $EXIT_CODE"
            ((FAILED_FILES++)) || true
        fi
    fi

    log_success ""

    if [[ "$DRY_RUN" == true ]] && (( TOTAL_FILES % PAUSE_EVERY == 0 )); then
        echo "----- Paused after $TOTAL_FILES files (dry-run) -----"
        echo "Press Enter to continue..."
        read -r
    fi
done

# ===== Summary =====
log_success "========================================="
if [[ "$DRY_RUN" == true ]]; then
    log_success "DRY-RUN Summary"
else
    log_success "Conversion Summary"
fi
log_success "Processed : $TOTAL_FILES"
log_success "Successful: $SUCCESS_FILES"
log_success "Failed    : $FAILED_FILES"

if [[ "$DRY_RUN" == false ]] && (( TOTAL_ORIGINAL_SIZE > 0 )); then
    TOTAL_REDUCTION=$((100 - TOTAL_OUTPUT_SIZE * 100 / TOTAL_ORIGINAL_SIZE))
    log_success "Size reduction: ${TOTAL_REDUCTION}%"
    log_success "Original total: $TOTAL_ORIGINAL_SIZE bytes"
    log_success "Output total  : $TOTAL_OUTPUT_SIZE bytes"
fi
log_success "Finished at [$(date)]"
log_success "========================================="