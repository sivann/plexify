#!/bin/bash

# FUNCTION: Automates the post-processing of media files for Plex.
# Includes smart renaming (Title (Year)), directory cleaning (junk removal),
# cross-device moving, and modern Plex API library refresh triggers.

# --- CONFIGURATION FILE FORMAT ---
# The script expects a configuration file at /opt/plex-token.conf
# The file must contain the following variable (no spaces around '='):
# plex_token=YOUR_X_PLEX_TOKEN_HERE
#
# RECOMMENDED PERMISSIONS:
# sudo chown root:root /opt/plex-token.conf
# sudo chmod 600 /opt/plex-token.conf
# ----------------------------------

SYSLOG_TAG="plexify"
CONFIG_FILE="/opt/plex-token.conf"

# Default Values (Adjust these as needed for your specific setup)
EXECUTE=false
CLEAN=false
MOVE=false
SCAN=false
REFRESH=false
SECTION_ID="1"          # The ID of your "Movies" library in Plex
PLEX_HOST="127.0.0.1"   # IP address of your Plex server
PLEX_PORT="32400"

# Load token from external file
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    PLEX_TOKEN="$plex_token"
fi

# --- LOGGING FUNCTION ---
log_action() {
    local msg="$1"
    local log_path="$2"
    local prefix="[DRY-RUN]"
    [[ "$EXECUTE" == true ]] && prefix="[ACTION]"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $prefix $msg" >> "$log_path"
    logger -t "$SYSLOG_TAG" "$prefix $msg"
    echo -e "$prefix $msg"
}

# --- HELP MENU ---
usage() {
    echo "Plexify: Rename, Clean, and API-based Management for Plex."
    echo ""
    echo "Usage: $(basename "$0") [OPTIONS] [input_path]"
    echo "  -x         Execute (actually move/rename/API call)."
    echo "  -c         Clean internal folder (rename movie, keep subs, delete junk)."
    echo "  -m         Move to target directory."
    echo "  -t PATH    Target directory (e.g. /media/storage/Movies/)."
    echo "  -s         Trigger Plex Scan (Detects new files in library)."
    echo "  -r         Trigger GLOBAL Refresh (Refreshes metadata for ALL films)."
    echo "  -h         Show this help."
    echo ""
    echo "Examples:"
    echo "  Just Scan:         plexify.sh -xs"
    echo "  Full Automation:   plexify.sh -xcm -s -t \"/media/4tb/Movies/\" \"%F\""
    exit 1
}

# --- PARSE OPTIONS ---
while getopts "xcmt:srh" opt; do
    case $opt in
        x) EXECUTE=true ;;
        c) CLEAN=true ;;
        m) MOVE=true ;;
        t) TARGET_DIR="$OPTARG" ;;
        s) SCAN=true ;;
        r) REFRESH=true ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

INPUT_PATH="$1"

# Define Log Path
if [[ -n "$INPUT_PATH" ]]; then
    ABS_INPUT=$(realpath "$INPUT_PATH")
    PARENT_DIR=$(dirname "$ABS_INPUT")
    LOG_FILE="$(dirname "$PARENT_DIR")/plexify_history.txt"
else
    LOG_FILE="/var/log/plexify.log"
fi

# --- STANDALONE API CALLS ---
if [[ -z "$INPUT_PATH" ]]; then
    if [[ "$SCAN" == true || "$REFRESH" == true ]]; then
        [[ -z "$PLEX_TOKEN" ]] && { echo "ERROR: PLEX_TOKEN not found in $CONFIG_FILE"; exit 1; }
        
        if [[ "$SCAN" == true ]]; then
            [[ "$EXECUTE" == true ]] && curl -s -G "http://$PLEX_HOST:$PLEX_PORT/library/sections/$SECTION_ID/refresh" -H "X-Plex-Token: $PLEX_TOKEN" > /dev/null
            log_action "Plex Scan Triggered (Library-wide detection)." "$LOG_FILE"
        fi
        
        if [[ "$REFRESH" == true ]]; then
            [[ "$EXECUTE" == true ]] && curl -s -G "http://$PLEX_HOST:$PLEX_PORT/library/sections/$SECTION_ID/refresh?force=1" -H "X-Plex-Token: $PLEX_TOKEN" > /dev/null
            log_action "Plex GLOBAL Refresh Triggered (Updating metadata for all films)." "$LOG_FILE"
        fi
        exit 0
    fi
    usage
fi

# --- SMART RENAME LOGIC ---
base_name=$(basename "$ABS_INPUT")
temp_name=$(echo "$base_name" | tr '._' ' ' | sed 's/[()]//g' | sed 's/[[:space:]]\+/ /g')
year=$(echo "$temp_name" | grep -oE '(19|20)[0-9]{2}' | head -1)

if [[ -n "$year" ]]; then
    title=$(echo "$temp_name" | sed -E "s/$year.*//; s/[[:space:]]+$//")
    clean_name="$title ($year)"
else
    clean_name=$(echo "$temp_name" | sed 's/[[:space:]]+$//')
fi

current_loc="$ABS_INPUT"

# --- 1. PARENT RENAME ---
if [[ "$base_name" != "$clean_name" ]]; then
    new_path="$PARENT_DIR/$clean_name"
    if [[ "$EXECUTE" == true ]]; then
        mv -n "$ABS_INPUT" "$new_path"
        current_loc="$new_path"
        log_action "RENAMED PARENT: $base_name -> $clean_name" "$LOG_FILE"
    else
        log_action "DRY-RUN: Would rename parent $base_name -> $clean_name" "$LOG_FILE"
        current_loc="$new_path"
    fi
else
    log_action "PARENT NAME OK: $base_name" "$LOG_FILE"
fi

# --- 2. INTERNAL CLEANING ---
if [[ "$CLEAN" == true ]]; then
    peek_loc="$ABS_INPUT"
    [[ "$EXECUTE" == true ]] && peek_loc="$current_loc"
    if [[ -d "$peek_loc" ]]; then
        (
            cd "$peek_loc" || exit
            movie_file=$(ls -S | grep -E "\.(mkv|mp4|avi)$" | head -1)
            if [[ -n "$movie_file" ]]; then
                ext="${movie_file##*.}"
                if [[ "$EXECUTE" == true ]]; then
                    mv "$movie_file" "$clean_name.$ext"
                    # Whitelist movie file and subtitles
                    find . -type f ! -name "$clean_name.$ext" ! -name "*.srt" ! -name "*.sub" ! -name "*.idx" -delete
                    log_action "CLEANED INTERNAL: Kept $clean_name.$ext and subs." "$LOG_FILE"
                else
                    log_action "DRY-RUN: Inside $clean_name, would rename $movie_file -> $clean_name.$ext" "$LOG_FILE"
                fi
            fi
        )
    fi
fi

# --- 3. MOVE & OPTIONAL API TRIGGER ---
if [[ "$MOVE" == true && -n "$TARGET_DIR" ]]; then
    if [[ -d "$TARGET_DIR" ]] || mountpoint -q "$TARGET_DIR"; then
        dest_path="$TARGET_DIR/$clean_name"
        if [[ "$(realpath "$current_loc")" != "$(realpath "$TARGET_DIR" 2>/dev/null)/$clean_name" ]]; then
            if [[ "$EXECUTE" == true ]]; then
                if mv --no-preserve=ownership -n "$current_loc" "$dest_path"; then
                    chown -R plex:plex "$dest_path" 2>/dev/null
                    chmod -R 755 "$dest_path" 2>/dev/null
                    
                    if [[ "$SCAN" == true && -n "$PLEX_TOKEN" ]]; then
                        curl -s -G "http://$PLEX_HOST:$PLEX_PORT/library/sections/$SECTION_ID/refresh" -H "X-Plex-Token: $PLEX_TOKEN" > /dev/null
                        log_action "SUCCESS: Moved & API Scanned: $clean_name" "$LOG_FILE"
                    fi
                    
                    if [[ "$REFRESH" == true && -n "$PLEX_TOKEN" ]]; then
                        curl -s -G "http://$PLEX_HOST:$PLEX_PORT/library/sections/$SECTION_ID/refresh?force=1" -H "X-Plex-Token: $PLEX_TOKEN" > /dev/null
                        log_action "GLOBAL REFRESH Triggered after move." "$LOG_FILE"
                    fi
                fi
            else
                log_action "DRY-RUN: Would move to $dest_path and notify Plex." "$LOG_FILE"
            fi
        fi
    fi
fi
