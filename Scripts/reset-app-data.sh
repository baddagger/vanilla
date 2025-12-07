#!/bin/bash

# For sandboxed apps, all data is in the container
rm -rf ~/Library/Containers/me.Vanilla-Player && echo "✓ Cleared all app data (sandboxed)" || echo "- No sandboxed container to clear"

# Fallback for non-sandboxed builds
defaults delete me.Vanilla-Player 2>/dev/null && echo "✓ Cleared preferences" || echo "- No preferences to clear"
rm -rf ~/Library/Application\ Support/VanillaPlayer && echo "✓ Cleared library" || echo "- No library to clear"
rm -rf ~/Library/Caches/VanillaPlayer && echo "✓ Cleared artwork cache" || echo "- No cache to clear"
