#!/usr/bin/env python3
"""Package this project into a release zip for GitHub Releases.

Creates `ComfyUI-Sage-EasyInstall.zip` at the repository root (that filename is
gitignored). Everything in the zip lives inside a single top-level folder named
`ComfyUI-Sage-EasyInstall`, so users who extract it get one tidy folder instead
of loose files.

Usage (from anywhere):
    python assets/tools/create_package.py
    python assets/tools/create_package.py --output D:\\somewhere\\ComfyUI-Sage-EasyInstall.zip

By default only files tracked by git are packaged (via `git ls-files`), which
keeps junk like .git, caches and editor folders out of the release. If git isn't
available, it falls back to walking the tree with a built-in exclude list.
"""

import argparse
import os
import subprocess
import sys
import zipfile

# The folder name that will wrap everything inside the zip, and the base name of
# the zip file itself (both without extension).
PACKAGE_NAME = "ComfyUI-Sage-EasyInstall"

# Repo root is two levels up from this script (assets/tools/create_package.py).
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Paths never included in the release, relative to the repo root (used for both
# the git and the fallback file listing). Directories match by prefix.
EXCLUDES = {
    ".git",
    ".github",
    ".claude",
    ".gitattributes",
    ".gitignore",
    "assets/tools",  # the packaging tooling itself doesn't belong in the release
}


def _is_excluded(rel_path):
    """True if a repo-relative path sits under any excluded file or folder."""
    rel_path = rel_path.replace("\\", "/")
    for ex in EXCLUDES:
        if rel_path == ex or rel_path.startswith(ex + "/"):
            return True
    return False


def _git_tracked_files():
    """Return repo-relative paths tracked by git, or None if git is unavailable."""
    try:
        out = subprocess.run(
            ["git", "ls-files"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    files = [line.strip() for line in out.stdout.splitlines() if line.strip()]
    return files or None


def _walked_files():
    """Fallback: every file under the repo root, minus the exclude list."""
    files = []
    for dirpath, dirnames, filenames in os.walk(REPO_ROOT):
        rel_dir = os.path.relpath(dirpath, REPO_ROOT)
        rel_dir = "" if rel_dir == "." else rel_dir.replace("\\", "/")
        # Prune excluded directories so we don't descend into them.
        dirnames[:] = [
            d for d in dirnames
            if not _is_excluded(f"{rel_dir}/{d}" if rel_dir else d)
        ]
        for name in filenames:
            rel = f"{rel_dir}/{name}" if rel_dir else name
            files.append(rel)
    return files


def collect_files():
    """Pick the files to package, preferring git's view of the project."""
    tracked = _git_tracked_files()
    source = "git ls-files" if tracked is not None else "filesystem walk"
    files = tracked if tracked is not None else _walked_files()
    files = [f for f in files if not _is_excluded(f)]
    # Only keep paths that actually exist on disk (git may list deleted files).
    files = [f for f in files if os.path.isfile(os.path.join(REPO_ROOT, f))]
    files.sort()
    return files, source


def build_zip(output_path):
    files, source = collect_files()
    if not files:
        print("ERROR: no files found to package.", file=sys.stderr)
        return 1

    os.makedirs(os.path.dirname(os.path.abspath(output_path)) or ".", exist_ok=True)

    print(f"Packaging {len(files)} files (source: {source})")
    print(f"  Wrapping under folder: {PACKAGE_NAME}/")
    with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for rel in files:
            abs_path = os.path.join(REPO_ROOT, rel)
            arcname = f"{PACKAGE_NAME}/{rel}"
            zf.write(abs_path, arcname)

    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"\nCreated: {output_path}  ({size_mb:.1f} MB)")
    print("Upload this file to:")
    print("  https://github.com/mickmumpitz/ComfyUI-Sage-EasyInstall/releases")
    return 0


def main():
    parser = argparse.ArgumentParser(description="Build the ComfyUI-Sage-EasyInstall release zip.")
    parser.add_argument(
        "--output",
        "-o",
        default=os.path.join(REPO_ROOT, f"{PACKAGE_NAME}.zip"),
        help=f"Output zip path (default: <repo root>/{PACKAGE_NAME}.zip)",
    )
    args = parser.parse_args()
    return build_zip(args.output)


if __name__ == "__main__":
    sys.exit(main())
