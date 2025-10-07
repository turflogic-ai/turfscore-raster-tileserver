#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(realpath "$0")"
cd /home/titiler/turfscore

# Save original args for replay
ORIGINAL_ARGS=("$@")

# Capture current state before pulling
PRE_REF="$(git rev-parse HEAD 2>/dev/null || echo "")"

# Get latest production branch (force to match remote exactly)
if ! git fetch origin production; then
    echo "Failed to fetch from origin" >&2
    exit 1
fi

if ! git reset --hard origin/production; then
    echo "Failed to reset to origin/production" >&2
    exit 1
fi

# Check if THIS script changed during the update
POST_REF="$(git rev-parse HEAD)"
SCRIPT_CHANGED=false

if [[ -n "$PRE_REF" && "$PRE_REF" != "$POST_REF" ]]; then
    if ! git diff --quiet "$PRE_REF" "$POST_REF" -- "$SCRIPT_PATH" 2>/dev/null; then
        SCRIPT_CHANGED=true
    fi
fi

# Reload script if it changed and we haven't already reloaded
if [[ "$SCRIPT_CHANGED" == "true" && "${1:-}" != "--reloaded" ]]; then
    echo "Script updated (commit: ${PRE_REF:0:8} -> ${POST_REF:0:8}), reloading..."
    exec "$SCRIPT_PATH" --reloaded "${ORIGINAL_ARGS[@]}"
fi

# Remove --reloaded flag if present
if [[ "${1:-}" == "--reloaded" ]]; then
    shift
fi

# --- Main deployment logic ---

# Verify virtual environment exists
if [[ ! -f .venv/bin/activate ]]; then
    echo "Error: Virtual environment not found at .venv/bin/activate" >&2
    exit 1
fi

source .venv/bin/activate

# Use python -m pip for safety
python -m pip install --upgrade pip --no-cache-dir

# Install requirements if file exists
if [[ -f requirements.txt ]]; then
    echo "Installing requirements from requirements.txt..."
    python -m pip install -r requirements.txt --no-cache-dir
else
    echo "No requirements.txt found, skipping dependency installation"
fi

# --- Flag handling ---
for arg in "${ORIGINAL_ARGS[@]}"; do
    case "$arg" in
        --restart-server)
            echo "Restarting TiTiler tile server..."
            if systemctl is-active --quiet turfscore-tileserver; then
                sudo systemctl restart turfscore-tileserver
            else
                sudo systemctl start turfscore-tileserver
            fi
            
            echo "Reloading Nginx..."
            if systemctl is-active --quiet nginx; then
                sudo systemctl reload nginx
            else
                sudo systemctl start nginx
            fi
            ;;
    esac
done

echo "Deployment completed successfully!"
