# Plexify

A robust Bash utility for automating the "Download-to-Plex" pipeline. `plexify` handles intelligent renaming, junk file purging, cross-filesystem moving, and triggers the modern Plex Media Server API for instant library updates.



## ✨ Features

- **Smart Renaming**: Automatically converts `Movie.Title.2024.1080p.Bluray.x264.mkv` to `Movie Title (2024).mkv`.
- **Junk Purge**: Deletes `.txt`, `.nfo`, and `.jpg` clutter while protecting the main movie and `.srt/.sub` subtitle files.
- **Safety First**: Verifies target directory exists or is a mount point before moving to prevent filling up your root partition.
- **Modern API Integration**: Uses the Plex Web API (`X-Plex-Token`) instead of deprecated CLI commands for faster, more reliable metadata matching.
- **Dry-Run Mode**: Every action can be simulated before execution to ensure your library stays organized.

## 🚀 Installation

1. **Download the script**:
   Place `plexify.sh` in `/usr/local/bin/` and make it executable:
   ```bash
   sudo chmod +x /usr/local/bin/plexify.sh
