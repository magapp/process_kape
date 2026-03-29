# Kape Parser – Web Interface

A Flask-based web interface for processing KAPE collection ZIP files.
Upload ZIP files via the browser, monitor processing in real time, and download results when done.

---

## Requirements

- Docker
- Docker Compose

---

## Directory structure

```
web/
├── app.py                  # Flask application
├── Dockerfile
├── compose.yml
├── requirements.txt
├── bin/
│   └── process_kape.sh     # Processing script (see below)
├── templates/
│   └── index.html
├── downloaded/             # Uploaded ZIP files land here (volume)
├── temporary_processing/   # Working directory during processing (volume)
│   ├── run.lock            # Exists while a job is running
│   └── run.log             # Live log output, tailed in the browser
└── result/                 # Output files, downloadable from the UI (volume)
```

---

## Building and running

### First build (slow — downloads wine, mono, PowerShell)

```bash
docker compose build
docker compose up -d
```

The first build takes several minutes because it installs:
- Wine + wine32
- wine-mono 11.0.0 (.NET support)
- PowerShell for Windows 7.4.6 (via wine)

### Start / stop

```bash
docker compose up -d      # start in background
docker compose down       # stop and remove container
docker compose logs -f    # follow Flask logs
```

### Open in browser

```
http://localhost:5000
```

---

## Upgrading

### You changed `process_kape.sh` or any app file

Just rebuild — Docker reuses all cached layers for wine/mono/PowerShell:

```bash
docker compose build
docker compose up -d
```

The expensive layers are cached and will be skipped. Only the `COPY` step re-runs.

### Force a complete rebuild (no cache)

```bash
docker compose build --no-cache
docker compose up -d
```

### Upgrading PowerShell version

Edit `PS_VERSION` in the Dockerfile:

```dockerfile
ENV PS_VERSION=7.4.6
```

Then rebuild. Only the PowerShell download layer and everything below it will re-run.

---

## How `process_kape.sh` works

The script is called automatically by the web interface after all ZIP files have been uploaded.
It receives three arguments:

```bash
bin/process_kape.sh <input_dir> <work_dir> <output_dir>
```

| Argument | Value | Description |
|---|---|---|
| `input_dir` | `downloaded` | Directory containing the uploaded ZIP files |
| `work_dir` | `temporary_processing` | Working directory for intermediate files |
| `output_dir` | `result` | Where finished output files are written |

### Expected behaviour

- Create `temporary_processing/run.lock` at the start and remove it when done.
  The web UI checks for this file to know whether a job is running.
- Write progress and status messages to `temporary_processing/run.log`.
  The web UI tails this file live in the browser while the job runs.
- Write output files to the `result/` directory.
  They appear as downloadable links in the browser after the job finishes.

### Minimal skeleton

```bash
#!/bin/bash
set -euo pipefail

INPUT_DIR="$1"
WORK_DIR="$2"
OUTPUT_DIR="$3"

LOCK="$WORK_DIR/run.lock"
LOG="$WORK_DIR/run.log"

touch "$LOCK"
exec > >(tee -a "$LOG") 2>&1

echo "Starting processing..."

# --- your logic here ---
# powershell -noni -f your_script.ps1 -InputDir "$INPUT_DIR" -OutputDir "$OUTPUT_DIR"

echo "Done."
rm -f "$LOCK"
```

### PowerShell inside the container

The container has PowerShell for Windows running via wine, available as `powershell`:

```bash
powershell -noni -c 'Write-Host "hello from pwsh"'
powershell -noni -File your_script.ps1 -Arg value
```

---

## Volumes

All three data directories are mounted from the host so data persists across container restarts
and is accessible outside Docker:

| Host path | Container path |
|---|---|
| `./downloaded` | `/app/downloaded` |
| `./temporary_processing` | `/app/temporary_processing` |
| `./result` | `/app/result` |
