# Plexify.sh

A robust Bash script designed to transform messy scene-release movie folders into Plex-perfect structures. It aggressively handles inconsistent naming, trailing release tags (like YTS.MX or RARBG), and automates subtitle organization.

## Features
- Nuclear Year-Cut: Isolates the movie title and year, vaporizing codecs, resolution, and group tags.
- YTS-MX Guard: Specifically handles dots inside brackets that often break standard renaming logic.
- Plex Subtitle Logic:
    - Recursively finds subtitles in subfolders and moves them to the root.
    - Maps 3-letter ISO codes (gre, fre, eng) to 2-letter Plex codes (el, fr, en).
    - Preserves descriptive labels (e.g., Brazilian.pt.srt) to avoid generic numbering.
- Automatic Cleanup: Deletes non-media junk (NFO, TXT, JPG) and prunes empty directories.
- Safe Execution: Includes a default Dry-Run mode to preview changes.

## Installation
1. Save the script as plexify.sh.
2. Make it executable:
   chmod +x plexify.sh
3. (Optional) Move to your bin:
   sudo mv plexify.sh /usr/local/bin/plexify

## Usage
Run the script against a movie folder:

plexify [OPTIONS] <TARGET_DIRECTORY>

### Options
- -x: Execute. Required to actually perform renames and deletions.
- -c: Clean. Triggers internal file renaming and junk removal.

### Example
Input: Lucky Baskhar (2024) [720p] [WEBRip] [YTS.MX]/
Command: plexify -x -c "Lucky Baskhar (2024) [720p] [WEBRip] [YTS.MX]/"
Result: Lucky Baskhar (2024)/Lucky Baskhar (2024).mp4

---

## License
MIT - Feel free to use and modify for your home server.
