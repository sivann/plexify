"""
# Plexify.sh

A robust Bash script designed to transform messy media folders into organized, Plex-compatible structures. It standardizes naming conventions, manages subtitles, and automates directory cleanup.

## Features
- **Smart Title Extraction:** Automatically isolates the media title and production year, stripping away technical metadata and release tags.
- **Subtitle Management:** - Recursively identifies subtitles in subfolders and moves them to the root.
    - Maps 3-letter ISO codes (e.g., gre, fre, eng) to 2-letter Plex-compatible codes (el, fr, en).
    - Maintains descriptive labels (e.g., 'SDH' or 'Forced') to preserve track identity.
- **Directory Sanitization:** Automatically purges empty subdirectories and non-essential metadata files after processing.
- **Dry-Run Support:** Includes a safety mode to preview all file operations before execution.

## Installation
1. Save the script as `plexify.sh`.
2. Grant execution permissions:
   `chmod +x plexify.sh`
3. (Optional) Move to a directory in your PATH:
   `sudo mv plexify.sh /usr/local/bin/plexify`

## Usage
Run the script against a target directory:

`plexify [OPTIONS] <TARGET_DIRECTORY>`

### Options
- `-x`: **Execute.** Required to perform actual file renames and deletions.
- `-c`: **Clean.** Triggers internal file renaming and the removal of junk files.

### Example
**Input:** `Media.Title.2024.1080p.BluRay.x264/`
**Command:** `plexify -x -c "Media.Title.2024.1080p.BluRay.x264/"`
**Result:** `Media Title (2024)/Media Title (2024).mkv`

---

## License
MIT - Open for personal use and modification.
"""
