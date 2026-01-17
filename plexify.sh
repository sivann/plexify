#!/bin/bash

# --- INITIALIZE LOGGING ---
SYSLOG_TAG="plexify"
RAW_PATH="${@: -1}"
if [[ -n "$RAW_PATH" && -e "$RAW_PATH" ]]; then
    LOG_FILE="$(dirname "$(realpath -- "$RAW_PATH")")/plexify_history.txt"
else
    LOG_FILE="/tmp/plexify_history.txt"
fi

log_action() {
    local msg="$1"
    local prefix="[DRY-RUN]"
    [[ "$EXECUTE" == true ]] && prefix="[ACTION]"
    local formatted_msg="$(date '+%Y-%m-%d %H:%M:%S') $prefix $msg"
    echo "$formatted_msg" >> "$LOG_FILE"
    echo -e "$formatted_msg"
}

# --- PARSE OPTIONS ---
EXECUTE=false; CLEAN=false; MOVE=false
while getopts "xcmtsrzu" opt; do
    case $opt in
        x) EXECUTE=true ;;
        c) CLEAN=true ;;
        m) MOVE=true ;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND - 1))
INPUT_PATH="${1%/}"  
[[ -z "$INPUT_PATH" ]] && exit 0

# --- SMART RENAME LOGIC ---
ABS_INPUT=$(realpath -- "$INPUT_PATH")
PARENT_DIR=$(dirname "$ABS_INPUT")
base_name=$(basename "$ABS_INPUT")
extension="${base_name##*.}"
[[ "$base_name" == "$extension" ]] && extension=""
name_no_ext="${base_name%.*}"

# V18 FIX: Sanitize EVERYTHING to spaces first. 
# This turns "[YTS.MX]" into " YTS MX " so dots don't protect the garbage.
clean_base=$(echo "$name_no_ext" | tr '._[]-' ' ' | sed 's/[()]/ /g' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Identify Year
year=$(echo "$clean_base" | grep -oE '(19|20)[0-9]{2}' | tail -1)

if [[ -n "$year" ]]; then
    # V18 HARD CUT: We take the first part of the string up to the year and drop EVERYTHING else.
    # The [[:space:]]* handling ensures no trailing dots or bracket-fragments remain.
    title=$(echo "$clean_base" | sed -E "s/^(.*)($year).*/\1/" | sed 's/[[:space:]]*$//')
    
    # If the year was the very start of the folder name
    [[ -z "$title" ]] && movie_base_name="($year)" || movie_base_name="$title ($year)"
else
    movie_base_name="$clean_base"
fi

movie_base_name=$(echo "$movie_base_name" | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
clean_name="$movie_base_name"
[[ -n "$extension" ]] && clean_name="$clean_name.$extension"

current_loc="$ABS_INPUT"

# 1. RENAME FOLDER/FILE
if [[ "$base_name" != "$clean_name" ]]; then
    new_path="$PARENT_DIR/$clean_name"
    if [[ "$EXECUTE" == true ]]; then
        mv -v -T -- "$ABS_INPUT" "$new_path" && current_loc="$new_path"
        log_action "RENAME: $base_name -> $clean_name"
    else
        log_action "DRY-RUN RENAME: $base_name -> $clean_name"
        current_loc="$new_path"
    fi
fi

# 2. INTERNAL CLEAN
if [[ -d "$current_loc" ]]; then
    movie_file=$(ls -S "$current_loc" | grep -E "\.(mkv|mp4|avi|m4v)$" | head -1)
    if [[ -n "$movie_file" ]]; then
        m_ext="${movie_file##*.}"
        target_movie_filename="$movie_base_name.$m_ext"

        if [[ "$CLEAN" == true && "$movie_file" != "$target_movie_filename" && "$EXECUTE" == true ]]; then
            mv -- "$current_loc/$movie_file" "$current_loc/$target_movie_filename"
            log_action "INTERNAL RENAME: $movie_file -> $target_movie_filename"
        fi

        # --- SUBTITLE HANDLING ---
        if [[ "$CLEAN" == true ]]; then
            find "$current_loc" -name "*.srt" -type f | while read -r srt; do
                s_base=$(basename "$srt")
                [[ "$s_base" =~ ^"${movie_base_name}"\..*\.srt$ ]] && continue
                [[ "$s_base" == "${movie_base_name}.srt" ]] && continue

                s_name_no_ext="${s_base%.*}"
                l=$(echo "$s_base" | tr '[:upper:]' '[:lower:]')
                
                lang=""
                [[ "$l" =~ "gre" || "$l" =~ "ell" || "$l" =~ "greek" ]] && lang="el"
                [[ "$l" =~ "eng" || "$l" =~ "english" ]] && lang="en"
                [[ "$l" =~ "fre" || "$l" =~ "fra" || "$l" =~ "french" ]] && lang="fr"
                [[ "$l" =~ "spa" || "$l" =~ "spanish" ]] && lang="es"

                # Strip redundant title/year/YTS junk from sub label
                sub_label=$(echo "$s_name_no_ext" | tr '._[]-' ' ' | sed "s/$year//g" | sed "s/YTS//gi" | sed "s/MX//gi" | tr '[:space:]' '.' | sed 's/\.\+/\./g' | sed 's/^\.*//;s/\.*$//')
                
                if [[ -n "$lang" ]]; then
                    [[ "$sub_label" == *"$lang" ]] && sub_label="${sub_label%.$lang}"
                    [[ -n "$sub_label" ]] && new_srt="${movie_base_name}.${sub_label}.${lang}.srt" || new_srt="${movie_base_name}.${lang}.srt"
                else
                    [[ -n "$sub_label" ]] && new_srt="${movie_base_name}.${sub_label}.srt" || new_srt="${movie_base_name}.srt"
                fi

                if [[ "$EXECUTE" == true ]]; then
                    mv -- "$srt" "$current_loc/$new_srt"
                    log_action "SUB RENAME: $s_base -> $new_srt"
                fi
            done
        fi
        
        if [[ "$CLEAN" == true && "$EXECUTE" == true ]]; then
            find "$current_loc" -type f ! -name "$target_movie_filename" ! -name "*.srt" ! -name "*.sub" ! -name "*.idx" -delete
            find "$current_loc" -mindepth 1 -type d -empty -delete
            log_action "CLEANUP: Removed junk"
        fi
    fi
fi
