#!/usr/bin/env python3
"""Bootstrap local skills and install ui-ux-pro-max into an agent skills directory."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile


DEFAULT_UI_REPO = "nextlevelbuilder/ui-ux-pro-max-skill"
DEFAULT_UI_REF = "main"
SUPPORTED_AGENTS = {"codex", "claude", "claude-code", "custom"}


class InstallError(Exception):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Install this repo's skills into an agent skills directory and optionally "
            "install ui-ux-pro-max from GitHub using the upstream manual-install path."
        )
    )
    parser.add_argument(
        "--agent",
        default="codex",
        choices=sorted(SUPPORTED_AGENTS),
        help="Target agent. Use custom with --dest for unknown agents.",
    )
    parser.add_argument(
        "--dest",
        help="Target skills directory. Defaults depend on --agent.",
    )
    parser.add_argument(
        "--repo-root",
        default=str(Path(__file__).resolve().parents[1]),
        help="Local skills repo root. Defaults to this script's parent repo.",
    )
    parser.add_argument(
        "--mode",
        choices=("symlink", "copy"),
        default="symlink",
        help="How to install local skills from this repo.",
    )
    parser.add_argument(
        "--skip-local",
        action="store_true",
        help="Skip installing this repo's local skills.",
    )
    parser.add_argument(
        "--skip-ui",
        action="store_true",
        help="Skip installing ui-ux-pro-max from GitHub.",
    )
    parser.add_argument(
        "--ui-repo",
        default=DEFAULT_UI_REPO,
        help="GitHub repo in owner/repo format for ui-ux-pro-max.",
    )
    parser.add_argument(
        "--ui-ref",
        default=DEFAULT_UI_REF,
        help="Git ref for ui-ux-pro-max.",
    )
    parser.add_argument(
        "--ui-path",
        help="Path inside the ui-ux-pro-max repo to copy. Defaults depend on --agent.",
    )
    parser.add_argument(
        "--ui-name",
        help="Destination directory name for ui-ux-pro-max. Defaults to source basename.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Replace existing destination entries.",
    )
    return parser.parse_args()


def default_dest(agent: str) -> Path | None:
    home = Path.home()
    if agent == "codex":
        codex_home = Path(os.environ.get("CODEX_HOME", home / ".codex"))
        return codex_home / "skills"
    if agent in {"claude", "claude-code"}:
        return home / ".claude" / "skills"
    return None


def default_ui_source(agent: str) -> tuple[str, str] | None:
    if agent == "codex":
        return ".codex/skills/ui-ux-pro-max", "ui-ux-pro-max"
    if agent in {"claude", "claude-code"}:
        return ".claude/skills/ui-ux-pro-max", "ui-ux-pro-max"
    return None


def discover_local_skills(repo_root: Path) -> list[Path]:
    skills: list[Path] = []
    for entry in sorted(repo_root.iterdir()):
        if not entry.is_dir():
            continue
        if entry.name.startswith("."):
            continue
        if entry.name == "scripts":
            continue
        if (entry / "SKILL.md").is_file():
            skills.append(entry)
    return skills


def ensure_empty_target(target: Path, force: bool) -> None:
    if not target.exists() and not target.is_symlink():
        return
    if not force:
        raise InstallError(f"Destination already exists: {target}")
    if target.is_symlink() or target.is_file():
        target.unlink()
        return
    shutil.rmtree(target)


def install_local_skill(src: Path, dest_root: Path, mode: str, force: bool) -> str:
    target = dest_root / src.name
    if mode == "symlink":
        if target.is_symlink() and target.resolve() == src.resolve():
            return f"local  {src.name:<22} already linked"
        ensure_empty_target(target, force)
        target.symlink_to(src, target_is_directory=True)
        return f"local  {src.name:<22} linked"

    if target.exists() and (target / "SKILL.md").is_file() and not force:
        return f"local  {src.name:<22} already present"
    ensure_empty_target(target, force)
    shutil.copytree(src, target, symlinks=True)
    return f"local  {src.name:<22} copied"


def github_zip_url(repo: str, ref: str) -> str:
    owner, name = repo.split("/", 1)
    return f"https://codeload.github.com/{owner}/{name}/zip/{ref}"


def safe_extract(zip_file: zipfile.ZipFile, dest_dir: Path) -> None:
    root = dest_dir.resolve()
    for member in zip_file.infolist():
        extracted = (dest_dir / member.filename).resolve()
        if extracted != root and not str(extracted).startswith(str(root) + os.sep):
            raise InstallError("Archive contains files outside the destination.")
    zip_file.extractall(dest_dir)


def download_repo(repo: str, ref: str) -> Path:
    temp_dir = Path(tempfile.mkdtemp(prefix="skill-bootstrap-"))
    zip_path = temp_dir / "repo.zip"
    try:
        with urllib.request.urlopen(github_zip_url(repo, ref)) as response:
            zip_path.write_bytes(response.read())
    except urllib.error.URLError as exc:
        raise InstallError(f"Failed to download {repo}@{ref}: {exc}") from exc

    with zipfile.ZipFile(zip_path, "r") as archive:
        safe_extract(archive, temp_dir)

    extracted_roots = [path for path in temp_dir.iterdir() if path.is_dir()]
    if len(extracted_roots) != 1:
        raise InstallError("Unexpected GitHub archive layout.")
    return extracted_roots[0]


def install_ui_skill(
    dest_root: Path,
    repo: str,
    ref: str,
    source_path: str,
    skill_name: str,
    force: bool,
) -> str:
    target = dest_root / skill_name
    if target.exists() and (target / "SKILL.md").is_file() and not force:
        return f"remote ui-ux-pro-max         already present"

    repo_root = download_repo(repo, ref)
    src = repo_root / source_path
    if not src.is_dir() or not (src / "SKILL.md").is_file():
        raise InstallError(f"ui-ux-pro-max source not found: {source_path}")

    ensure_empty_target(target, force)
    shutil.copytree(src, target, symlinks=True)
    return f"remote ui-ux-pro-max         installed from {repo}@{ref}"


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    if not repo_root.is_dir():
        raise InstallError(f"Repo root not found: {repo_root}")

    dest = Path(args.dest).expanduser().resolve() if args.dest else default_dest(args.agent)
    if dest is None:
        raise InstallError("Could not infer --dest for this agent. Pass --dest explicitly.")
    dest.mkdir(parents=True, exist_ok=True)

    ui_source = args.ui_path
    ui_name = args.ui_name
    if not args.skip_ui:
        defaults = default_ui_source(args.agent)
        if ui_source is None:
            if defaults is None:
                raise InstallError("Pass --ui-path for this agent, or use --skip-ui.")
            ui_source = defaults[0]
        if ui_name is None:
            ui_name = defaults[1] if defaults else Path(ui_source).name

    results: list[str] = []

    if not args.skip_local:
        local_skills = discover_local_skills(repo_root)
        if not local_skills:
            raise InstallError(f"No local skills found under {repo_root}")
        for skill_dir in local_skills:
            results.append(install_local_skill(skill_dir, dest, args.mode, args.force))

    if not args.skip_ui:
        assert ui_source is not None
        assert ui_name is not None
        results.append(
            install_ui_skill(dest, args.ui_repo, args.ui_ref, ui_source, ui_name, args.force)
        )

    print(f"Target skills dir: {dest}")
    for line in results:
        print(line)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except InstallError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
