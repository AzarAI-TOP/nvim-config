# Pinned bootstrap asset versions, parsed by bootstrap-windows.ps1's
# Read-VersionsFile (KEY="VALUE" lines; # comments and blank lines are
# skipped). SHA-256 comes from the GitHub Release asset digest. Windows-only:
# the Linux bootstrap and its nvim/fzf pins were removed (2026-08).
#
# Upgrading the font: set NERD_FONTS_VERSION to the new tag, then copy the
# SHA-256 of the exact "0xProto.zip" release asset (Release page → asset →
# expand "digest" or `curl -sL <asset-url> | sha256sum`). The digest
# must match this file or the bootstrap aborts — that is the point.

NERD_FONTS_VERSION="3.5.0"
OXPROTO_SHA256_ZIP="96044c9b041dbe6341a2e8b831259ba8e60f4646e55b721b5f6577505381df1f"
