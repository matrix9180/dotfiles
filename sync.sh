#!/bin/bash
# Sync omarchy config changes to this dotfiles repo, then commit and push.
#
# Usage:
#   ./sync.sh           # sync, commit, and push
#   ./sync.sh --dry-run # show what would change without committing

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$HOME/.config"
DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

sync_dir() {
    local rel="$1"
    local src="$CONFIG/$rel/"
    local dst="$DOTFILES/$rel/"
    if [[ -d "$src" ]]; then
        mkdir -p "$dst"
        if $DRY_RUN; then
            rsync -a --delete --dry-run "$src" "$dst"
        else
            rsync -a --delete "$src" "$dst"
        fi
    fi
}

sync_file() {
    local rel="$1"
    local src="$CONFIG/$rel"
    local dst="$DOTFILES/$rel"
    if [[ -f "$src" ]]; then
        if $DRY_RUN; then
            echo "would copy: $src -> $dst"
        else
            cp "$src" "$dst"
        fi
    fi
}

echo "Syncing config files..."

# Full directory mirrors
for dir in hypr waybar alacritty kitty ghostty mako swayosd omarchy walker; do
    sync_dir "$dir"
done

# Single top-level files
sync_file "starship.toml"

if $DRY_RUN; then
    echo "Dry run complete. No changes committed."
    exit 0
fi

cd "$DOTFILES"

if git diff --quiet && git diff --cached --quiet; then
    echo "No changes to commit."
    exit 0
fi

git add -A
git commit -m "chore: sync omarchy config $(date '+%Y-%m-%d %H:%M')"
git push

echo "Done: dotfiles synced and pushed."
