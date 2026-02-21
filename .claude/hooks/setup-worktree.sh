#!/bin/bash
# Symlinks .env and storage/*.sqlite3 files from the main worktree
# when Claude is running inside a git worktree.

MAIN_TREE="$(git worktree list --porcelain | head -1 | sed 's/worktree //')"
CURRENT="$(pwd)"

# Only run if we're in a worktree (not the main tree)
if [ "$CURRENT" = "$MAIN_TREE" ]; then
  exit 0
fi

# Symlink .env
if [ ! -e "$CURRENT/.env" ] && [ -f "$MAIN_TREE/.env" ]; then
  ln -s "$MAIN_TREE/.env" "$CURRENT/.env"
fi

# Symlink each sqlite3 file from main storage/ into worktree storage/
if [ -d "$MAIN_TREE/storage" ]; then
  mkdir -p "$CURRENT/storage"
  for db in "$MAIN_TREE"/storage/*.sqlite3*; do
    [ -e "$db" ] || continue
    base="$(basename "$db")"
    if [ ! -e "$CURRENT/storage/$base" ]; then
      ln -s "$db" "$CURRENT/storage/$base"
    fi
  done
fi
