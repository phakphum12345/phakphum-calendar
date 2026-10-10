#!/usr/bin/env python3
"""Validate the canonical DISKPATH repository manifest."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path


SCHEMA_VERSION = 1
MANIFEST_JSON = Path("DISKPATH.json")
MANIFEST_MD = Path("DISKPATH.md")

EXCLUDED_PATHS = {
    "DISKPATH.json",
    "DISKPATH.md",
}

def fail(message: str) -> int:
    print(f"DISKPATH VALIDATION: FAIL - {message}")
    return 1


def repository_root() -> Path:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        check=True,
        capture_output=True,
        text=True,
    )
    return Path(result.stdout.strip()).resolve()


def tracked_blobs(root: Path) -> list[tuple[str, str]]:
    result = subprocess.run(
        ["git", "ls-files", "--stage", "-z"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    files = []
    for record in result.stdout.split(b"\0"):
        if not record:
            continue
        metadata, raw_path = record.split(b"\t", 1)
        mode, oid, stage = metadata.decode("ascii").split()
        path = raw_path.decode("utf-8")
        if stage == "0" and mode in ("100644", "100755") and path not in EXCLUDED_PATHS:
            files.append((path, oid))
    return sorted(files)


def git_blob(root: Path, oid: str) -> bytes:
    result = subprocess.run(
        ["git", "cat-file", "blob", oid],
        cwd=root,
        check=True,
        capture_output=True,
    )
    return result.stdout


def load_manifest() -> dict:
    try:
        return json.loads(
            MANIFEST_JSON.read_text(encoding="utf-8")
        )
    except Exception as exc:
        raise ValueError(
            f"DISKPATH.json is invalid JSON: {exc}"
        ) from exc


def validate_schema(manifest: dict) -> None:
    required = {
        "schema_version",
        "generator",
        "manifest_scope",
        "excluded_paths",
        "file_count",
        "files",
    }

    if not isinstance(manifest, dict):
        raise ValueError("manifest root must be an object.")

    missing = sorted(required - set(manifest))
    if missing:
        raise ValueError(
            "DISKPATH.json missing required keys: "
            + ", ".join(missing)
        )

    if manifest["schema_version"] != SCHEMA_VERSION:
        raise ValueError(
            f"unsupported schema_version="
            f"{manifest['schema_version']}"
        )

    if manifest["manifest_scope"] != "git-tracked-regular-files":
        raise ValueError(
            "unexpected manifest_scope="
            f"{manifest['manifest_scope']!r}"
        )

    if not isinstance(manifest["generator"], dict):
        raise ValueError("generator must be an object.")

    for key in ("name", "version"):
        if not isinstance(manifest["generator"].get(key), str):
            raise ValueError(
                f"generator.{key} must be a string."
            )

    if not isinstance(manifest["excluded_paths"], list):
        raise ValueError("excluded_paths must be a list.")

    if set(manifest["excluded_paths"]) != EXCLUDED_PATHS:
        raise ValueError(
            "excluded_paths does not match the canonical exclusion set."
        )

    if not isinstance(manifest["file_count"], int):
        raise ValueError("file_count must be an integer.")

    if not isinstance(manifest["files"], list):
        raise ValueError("files must be a list.")

    if manifest["file_count"] != len(manifest["files"]):
        raise ValueError(
            "file_count does not match the number of file entries."
        )


def validate_entries(root: Path, manifest: dict) -> None:
    blobs = dict(tracked_blobs(root))
    expected_paths = sorted(blobs)

    manifest_entries = manifest["files"]

    manifest_paths = []

    for entry in manifest_entries:
        if not isinstance(entry, dict):
            raise ValueError("file entry is not an object.")

        for key in ("path", "size", "sha256"):
            if key not in entry:
                raise ValueError(
                    f"file entry missing {key!r}."
                )

        path = entry["path"]

        if not isinstance(path, str) or not path:
            raise ValueError(
                "file path must be a non-empty string."
            )

        if path in EXCLUDED_PATHS:
            raise ValueError(
                f"excluded path appears in manifest: {path}"
            )

        if path in manifest_paths:
            raise ValueError(
                f"duplicate path: {path}"
            )

        manifest_paths.append(path)

        size = entry["size"]

        if not isinstance(size, int) or size < 0:
            raise ValueError(
                f"invalid size for {path}"
            )

        digest = entry["sha256"]

        if (
            not isinstance(digest, str)
            or len(digest) != 64
            or any(
                character not in "0123456789abcdef"
                for character in digest
            )
        ):
            raise ValueError(
                f"invalid SHA-256 for {path}"
            )

    manifest_paths.sort()

    if manifest_paths != expected_paths:
        missing = sorted(
            set(expected_paths) - set(manifest_paths)
        )
        extra = sorted(
            set(manifest_paths) - set(expected_paths)
        )

        details = []

        if missing:
            details.append(
                "missing=" + ",".join(missing[:20])
            )

        if extra:
            details.append(
                "extra=" + ",".join(extra[:20])
            )

        raise ValueError(
            "manifest paths do not match git-tracked files"
            + (f" ({'; '.join(details)})" if details else "")
        )

    entries_by_path = {
        entry["path"]: entry
        for entry in manifest_entries
    }

    for path in expected_paths:
        entry = entries_by_path[path]
        content = git_blob(root, blobs[path])
        actual_size = len(content)

        if actual_size != entry["size"]:
            raise ValueError(
                f"size mismatch for {path}: "
                f"manifest={entry['size']} "
                f"actual={actual_size}"
            )

        actual_sha256 = hashlib.sha256(content).hexdigest()

        if actual_sha256 != entry["sha256"]:
            raise ValueError(
                f"SHA-256 mismatch for {path}: "
                f"manifest={entry['sha256']} "
                f"actual={actual_sha256}"
            )


def validate_markdown() -> None:
    if not MANIFEST_MD.exists():
        raise ValueError("DISKPATH.md is missing.")

    markdown = MANIFEST_MD.read_text(encoding="utf-8")

    required_markers = (
        "# DISKPATH",
        "## Purpose",
        "## Generator",
        "## Scope",
        "## Repository Paths",
        "## Integrity",
    )

    for marker in required_markers:
        if marker not in markdown:
            raise ValueError(
                f"DISKPATH.md missing marker: {marker}"
            )


def main() -> int:
    root = repository_root()

    if not MANIFEST_JSON.exists():
        return fail("DISKPATH.json is missing.")

    try:
        manifest = load_manifest()
        validate_schema(manifest)
        validate_entries(root, manifest)
        validate_markdown()
    except ValueError as exc:
        return fail(str(exc))

    print(
        "DISKPATH VALIDATION: PASS "
        f"({manifest['file_count']} tracked files)"
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())
