#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import sqlite3
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path


TAG_PATTERN = re.compile(r"^v(?P<version>[0-9]+\.[0-9]+\.[0-9]+)$")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Verify a published SiYuan release locally and through OpenList.",
    )
    parser.add_argument("--release-root", required=True, type=Path)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--public-url")
    parser.add_argument("--mount-path", default="/思源笔记")
    parser.add_argument("--database", type=Path)
    parser.add_argument("--password-env")
    parser.add_argument("--local-only", action="store_true")
    return parser.parse_args()


def expected_assets(version):
    return {
        "SHA256SUMS.txt",
        f"siyuan-{version}-linux.AppImage",
        f"siyuan-{version}-linux.deb",
        f"siyuan-{version}-linux.rpm",
        f"siyuan-{version}-linux.tar.gz",
        f"siyuan-{version}-mac-arm64.dmg",
        f"siyuan-{version}-mac.dmg",
        f"siyuan-{version}-win.exe",
        f"siyuan-{version}.apk",
    }


def resolve_version_dir(release_root, tag):
    root = release_root.resolve(strict=True)
    unresolved_version_dir = root / tag
    if unresolved_version_dir.is_symlink():
        raise ValueError("Version path must not be a symbolic link")
    version_dir = unresolved_version_dir.resolve(strict=True)
    if version_dir.parent != root:
        raise ValueError("Version directory escapes the release root")
    if not version_dir.is_dir() or version_dir.is_symlink():
        raise ValueError("Version path is not a regular directory")
    return version_dir


def read_manifest(manifest_path):
    checksums = {}
    for line in manifest_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        parts = line.split(maxsplit=1)
        if len(parts) != 2 or not re.fullmatch(r"[0-9a-fA-F]{64}", parts[0]):
            raise ValueError("SHA256SUMS.txt contains an invalid line")
        filename = parts[1].lstrip("* ")
        if not filename or Path(filename).name != filename or filename in checksums:
            raise ValueError("SHA256SUMS.txt contains an unsafe or duplicate filename")
        checksums[filename] = parts[0].lower()
    return checksums


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_local(release_root, tag, version):
    version_dir = resolve_version_dir(release_root, tag)
    expected = expected_assets(version)
    entries = list(version_dir.iterdir())
    names = {entry.name for entry in entries}
    if names != expected:
        raise ValueError("Local asset set does not match the expected release assets")
    for entry in entries:
        if entry.is_symlink() or not entry.is_file() or entry.stat().st_size <= 0:
            raise ValueError(f"Invalid local asset: {entry.name}")

    manifest = read_manifest(version_dir / "SHA256SUMS.txt")
    package_names = expected - {"SHA256SUMS.txt"}
    if set(manifest) != package_names:
        raise ValueError("SHA256SUMS.txt does not cover exactly the eight packages")
    for filename, expected_digest in manifest.items():
        if sha256_file(version_dir / filename) != expected_digest:
            raise ValueError(f"SHA256 mismatch: {filename}")

    return expected


def load_password(database, mount_path, password_env):
    if password_env:
        if password_env not in os.environ:
            raise ValueError(f"Password environment variable is missing: {password_env}")
        return os.environ[password_env]
    if not database:
        return ""
    database_path = database.resolve(strict=True)
    connection = sqlite3.connect(f"file:{database_path}?mode=ro", uri=True)
    try:
        row = connection.execute(
            "SELECT password FROM x_meta WHERE path = ?",
            (mount_path,),
        ).fetchone()
    finally:
        connection.close()
    return row[0] if row and row[0] else ""


def post_json(base_url, endpoint, payload):
    request = urllib.request.Request(
        urllib.parse.urljoin(f"{base_url.rstrip('/')}/", endpoint.lstrip("/")),
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "User-Agent": "SiYuan-Release-To-OpenList-Skill/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        try:
            result = json.load(error)
        except (json.JSONDecodeError, UnicodeDecodeError):
            result = {"code": None, "message": "Non-JSON HTTP error"}
        return error.code, result


def require_api_success(http_status, result, operation):
    if http_status != 200 or result.get("code") != 200:
        raise ValueError(f"OpenList {operation} request failed")
    return result.get("data") or {}


def verify_public(public_url, mount_path, tag, expected, password):
    version_path = f"{mount_path.rstrip('/')}/{tag}"
    list_payload = {
        "password": password,
        "page": 1,
        "per_page": 200,
        "refresh": False,
    }
    mount_status, mount_result = post_json(
        public_url,
        "/api/fs/list",
        {**list_payload, "path": mount_path},
    )
    mount_data = require_api_success(mount_status, mount_result, "mount list")
    mount_names = {item.get("name") for item in mount_data.get("content") or []}
    if tag not in mount_names:
        raise ValueError("Published version is not visible in the OpenList mount")

    version_status, version_result = post_json(
        public_url,
        "/api/fs/list",
        {**list_payload, "path": version_path},
    )
    version_data = require_api_success(version_status, version_result, "version list")
    content = version_data.get("content") or []
    names = {item.get("name") for item in content}
    if names != expected:
        raise ValueError("Public OpenList asset set does not match the expected release assets")
    if any(item.get("is_dir") or int(item.get("size") or 0) <= 0 for item in content):
        raise ValueError("Public OpenList contains a directory or empty asset")

    get_status, get_result = post_json(
        public_url,
        "/api/fs/get",
        {"path": f"{version_path}/SHA256SUMS.txt", "password": password},
    )
    get_data = require_api_success(get_status, get_result, "file get")
    raw_url = get_data.get("raw_url")
    if not raw_url:
        raise ValueError("OpenList did not return a download URL")
    range_request = urllib.request.Request(
        urllib.parse.urljoin(f"{public_url.rstrip('/')}/", raw_url),
        headers={
            "Range": "bytes=0-0",
            "User-Agent": "SiYuan-Release-To-OpenList-Skill/1.0",
        },
    )
    try:
        with urllib.request.urlopen(range_request, timeout=30) as response:
            range_status = response.status
            range_length = len(response.read())
    except urllib.error.HTTPError as error:
        range_status = error.code
        range_length = 0
    if range_status != 206 or range_length != 1:
        raise ValueError("OpenList Range verification failed")

    write_test_path = f"{version_path}/.siyuan-release-to-openlist-write-test-{uuid.uuid4().hex}"
    mkdir_status, mkdir_result = post_json(
        public_url,
        "/api/fs/mkdir",
        {"path": write_test_path},
    )
    mkdir_code = mkdir_result.get("code")
    if mkdir_status != 200 or mkdir_code != 403:
        detail = ""
        if mkdir_status == 200 and mkdir_code == 200:
            detail = f"; unexpected path may exist: {write_test_path}"
        raise ValueError(f"Anonymous write rejection verification failed{detail}")

    return {
        "mount_http_status": mount_status,
        "mount_api_code": mount_result.get("code"),
        "version_visible": True,
        "asset_count": len(content),
        "asset_set_matches": True,
        "all_files_nonempty": True,
        "range_status": range_status,
        "range_length": range_length,
        "mkdir_http_status": mkdir_status,
        "mkdir_api_code": mkdir_code,
    }


def main():
    args = parse_args()
    match = TAG_PATTERN.fullmatch(args.tag)
    if not match:
        raise ValueError("Tag must match vX.Y.Z")
    expected = verify_local(args.release_root, args.tag, match.group("version"))
    result = {
        "tag": args.tag,
        "local_asset_count": len(expected),
        "local_asset_set_matches": True,
        "sha256_verified_packages": 8,
    }
    if not args.local_only:
        if not args.public_url:
            raise ValueError("--public-url is required unless --local-only is used")
        password = load_password(args.database, args.mount_path, args.password_env)
        result.update(
            verify_public(args.public_url, args.mount_path, args.tag, expected, password),
        )
    print(json.dumps(result, ensure_ascii=True, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
