# Audacity → Podcast Chapters Automation

This repository contains scripts that automate preparing MP3 file to be published as an podcast episode that contains chapters (converting **Audacity label tracks** into **podcast chapters**), episode artwork and episode description, from original audio edited using Audacity (well, any MP3 will do regardless of origin, but chapters are in Audicity export label format).

The scripts handle:

- Audacity label export (`start<TAB>end<TAB>title`)
- Chapter metadata generation
- Correct last-chapter duration
- Loudness normalization (EBU R128)
- Re-encoding to **64 kbps MP3**
- Embedding podcast & episode metadata
- Embedding episode artwork

Two implementations are provided:
- **Pure Bash/AWK version (recommended)**
- **Python-assisted version**

---

## 📁 Repository Contents

| File | Description |
|-----|-------------|
| `prepare_episode_bashonly.sh` | **Pure Bash/AWK solution** (no Python required) |
| `prepare_episode.sh` | Python-assisted version (same functionality) |
| `README.md` | This documentation |

---

## 🎧 Input Requirements

### 1. Audio file
- `mp3`, `wav`, or `m4a`
- Example: `episode_raw.mp3`

### 2. Audacity labels file
Exported from:

```
Audacity → File → Export → Export Labels…
```

Expected format (tab-separated):

```
0.000000	0.000000	Vreme slava
350.369268	350.369268	Appleova zabava se nastavlja
1665.646014	1665.646014	Omaklo se Appleu
...
```

- **Column 1**: start time (seconds)
- **Column 2**: end time (ignored)
- **Column 3+**: chapter title (UTF-8 safe)

### 3. Artwork
- `jpg` or `png`
- Example: `cover.jpg`

---

## ⚙️ Dependencies

Required tools (must be in `$PATH`):

- `ffmpeg`
- `ffprobe`
- `awk`
- `bash`

Install on macOS:

```
brew install ffmpeg
```

---

## 🚀 Recommended Script (No Python)

### `prepare_episode_bashonly.sh`

This is the **recommended** version.

### Usage

```
./prepare_episode_bashonly.sh \
  episode_raw.mp3 \
  episode_labels.txt \
  "Podcast Title" \
  "Episode Title" \
  "Episode summary goes here." \
  cover.jpg
```

### What it does

- Reads Audacity labels
- Builds proper `FFMETADATA1` chapter blocks
- Uses **real audio duration** for the last chapter
- Loudness normalization using `loudnorm`
- Re-encodes audio to **64 kbps MP3**
- Embeds:
  - Podcast title
  - Episode title
  - Episode summary
  - Episode artwork
  - Chapter markers

### Output

```
episode_raw_chapters_64kbps_norm_tagged.mp3
```


---

## 🐍 Python-Assisted Script

### `prepare_episode.sh`

Functionally identical to the Bash version, but:

- Uses embedded Python for chapter metadata generation
- Requires `python3` to be available

Provided mainly for readability or if you prefer Python over AWK.

---

## 🔊 Loudness Notes

Default loudness target:

```
I = -23 LUFS (EBU R128)
```

If you prefer typical podcast loudness:

- Stereo podcast: `-16 LUFS`
- Mono podcast: `-19 LUFS`

Change this line in either script:

```
-filter:a loudnorm=I=-23:LRA=7:TP=-2:dual_mono=true
```

---

## 🔍 Inspecting Chapters

To inspect chapters in the final MP3:

```
ffprobe -v error -show_chapters -print_format json episode.mp3
```

To dump full metadata:

```
ffmpeg -i episode.mp3 -f ffmetadata -
```

---

## ✅ Why This Exists

Audacity does **not** export chapters in a format directly usable by most podcast tools.  
These scripts bridge that gap and make chapter creation:

- deterministic
- automatable
- reproducible
- CI-friendly

---

## 📄 License

MIT License.

