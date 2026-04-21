#!/bin/sh
set -eu

DEFAULT_UI_REPO="nextlevelbuilder/ui-ux-pro-max-skill"
DEFAULT_UI_REF="main"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEFAULT_REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

abspath() {
  if [ -d "$1" ]; then
    (
      cd -- "$1"
      pwd
    )
    return 0
  fi

  abs_dir=$(dirname -- "$1")
  abs_base=$(basename -- "$1")
  (
    cd -- "$abs_dir"
    printf '%s/%s\n' "$(pwd)" "$abs_base"
  )
}

expand_path() {
  case "$1" in
    "~")
      printf '%s\n' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s\n' "$HOME" "${1#~/}"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

default_dest() {
  case "$1" in
    codex)
      if [ -n "${CODEX_HOME:-}" ]; then
        printf '%s/skills\n' "$CODEX_HOME"
      else
        printf '%s/.codex/skills\n' "$HOME"
      fi
      ;;
    claude|claude-code)
      printf '%s/.claude/skills\n' "$HOME"
      ;;
    *)
      return 1
      ;;
  esac
}

discover_ui_source() {
  repo_root=$1
  skill_name=$2
  for candidate in \
    ".codex/skills/$skill_name" \
    ".claude/skills/$skill_name" \
    "skills/$skill_name" \
    "src/$skill_name"
  do
    if [ -d "$repo_root/$candidate" ] && [ -f "$repo_root/$candidate/SKILL.md" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

prompt_value() {
  prompt=$1
  default_value=$2

  while :; do
    if [ -n "$default_value" ]; then
      printf '%s [%s]: ' "$prompt" "$default_value" >&2
    else
      printf '%s: ' "$prompt" >&2
    fi

    IFS= read -r reply || die "Input aborted."

    if [ -n "$reply" ]; then
      printf '%s\n' "$reply"
      return 0
    fi

    if [ -n "$default_value" ]; then
      printf '%s\n' "$default_value"
      return 0
    fi
  done
}

prompt_agent() {
  while :; do
    value=$(prompt_value "Target agent [1 codex, 2 claude, 3 claude-code, 4 custom]" "1")
    case "$value" in
      1)
        printf 'codex\n'
        return 0
        ;;
      2)
        printf 'claude\n'
        return 0
        ;;
      3)
        printf 'claude-code\n'
        return 0
        ;;
      4)
        printf 'custom\n'
        return 0
        ;;
      codex|claude|claude-code|custom)
        printf '%s\n' "$value"
        return 0
        ;;
      *)
        printf 'Please enter 1-4 or codex, claude, claude-code, custom.\n' >&2
        ;;
    esac
  done
}

prompt_mode() {
  while :; do
    value=$(prompt_value "Install mode [1 symlink, 2 copy]" "1")
    case "$value" in
      1)
        printf 'symlink\n'
        return 0
        ;;
      2)
        printf 'copy\n'
        return 0
        ;;
      symlink|copy)
        printf '%s\n' "$value"
        return 0
        ;;
      *)
        printf 'Please enter 1-2 or symlink, copy.\n' >&2
        ;;
    esac
  done
}

prompt_dest() {
  agent=$1
  default_value=
  if dest_guess=$(default_dest "$agent"); then
    default_value=$dest_guess
  fi

  while :; do
    value=$(prompt_value "Target skills directory" "$default_value")
    [ -n "$value" ] || continue
    printf '%s\n' "$(expand_path "$value")"
    return 0
  done
}

confirm_install() {
  while :; do
    value=$(prompt_value "Proceed with installation? (y/n)" "y")
    case "$value" in
      y|Y|yes|YES|Yes)
        return 0
        ;;
      n|N|no|NO|No)
        printf 'Installation cancelled.\n'
        exit 0
        ;;
      *)
        printf 'Please enter y or n.\n' >&2
        ;;
    esac
  done
}

discover_local_skills() {
  repo_root=$1
  for entry in "$repo_root"/*; do
    [ -d "$entry" ] || continue
    name=$(basename -- "$entry")
    case "$name" in
      .*|scripts|skills)
        continue
        ;;
    esac
    [ -f "$entry/SKILL.md" ] || continue
    printf '%s\n' "$entry"
  done
}

ensure_empty_target() {
  target=$1
  force=$2
  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    return 0
  fi
  [ "$force" = "1" ] || die "Destination already exists: $target"
  rm -rf -- "$target"
}

install_skill() {
  src=$1
  dest_root=$2
  skill_name=$3
  mode=$4
  force=$5
  target=$dest_root/$skill_name
  src_abs=$(abspath "$src")

  if [ "$mode" = "symlink" ]; then
    if [ -L "$target" ] && [ "$(readlink -- "$target")" = "$src_abs" ]; then
      printf 'local  %-22s already linked\n' "$skill_name"
      return 0
    fi
    ensure_empty_target "$target" "$force"
    ln -s -- "$src_abs" "$target"
    printf 'local  %-22s linked\n' "$skill_name"
    return 0
  fi

  if [ -d "$target" ] && [ -f "$target/SKILL.md" ] && [ "$force" != "1" ]; then
    printf 'local  %-22s already present\n' "$skill_name"
    return 0
  fi

  ensure_empty_target "$target" "$force"
  cp -a -- "$src" "$target"
  printf 'local  %-22s copied\n' "$skill_name"
}

download_ui_cache() {
  cache_root=$1
  repo=$2
  ref=$3
  source_path=$4
  skill_name=$5
  force=$6
  cache_dir=$cache_root/$skill_name

  if [ -d "$cache_dir" ] && [ -f "$cache_dir/SKILL.md" ] && [ "$force" != "1" ]; then
    printf 'cache  %-22s already present\n' "$skill_name"
    return 0
  fi

  case "$repo" in
    */*)
      owner=${repo%%/*}
      name=${repo#*/}
      ;;
    *)
      die "Invalid --ui-repo, expected owner/repo: $repo"
      ;;
  esac

  require_cmd curl
  require_cmd unzip

  mkdir -p -- "$cache_root"
  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/skill-bootstrap.XXXXXX")

  cleanup_download() {
    rm -rf -- "$tmpdir"
  }

  trap cleanup_download EXIT HUP INT TERM

  archive=$tmpdir/repo.zip
  url=https://codeload.github.com/$owner/$name/zip/$ref

  curl -fsSL "$url" -o "$archive" || die "Failed to download $repo@$ref"
  unzip -q "$archive" -d "$tmpdir" || die "Failed to extract $repo@$ref"

  extracted_root=
  extracted_count=0
  for entry in "$tmpdir"/*; do
    [ -d "$entry" ] || continue
    extracted_root=$entry
    extracted_count=$((extracted_count + 1))
  done
  [ "$extracted_count" -eq 1 ] || die "Unexpected GitHub archive layout."

  resolved_source_path=$source_path
  if [ -z "$resolved_source_path" ]; then
    resolved_source_path=$(discover_ui_source "$extracted_root" "$skill_name") \
      || die "Could not find $skill_name in downloaded repo. Pass --ui-path explicitly."
  fi

  src=$extracted_root/$resolved_source_path
  [ -d "$src" ] || die "ui-ux-pro-max source not found: $resolved_source_path"
  [ -f "$src/SKILL.md" ] || die "ui-ux-pro-max source missing SKILL.md: $resolved_source_path"

  rm -rf -- "$cache_dir"
  cp -RL -- "$src" "$cache_dir"
  printf 'cache  %-22s downloaded from %s@%s (%s)\n' "$skill_name" "$repo" "$ref" "$resolved_source_path"

  trap - EXIT HUP INT TERM
  cleanup_download
}

REPO_ROOT=$DEFAULT_REPO_ROOT
UI_REPO=$DEFAULT_UI_REPO
UI_REF=$DEFAULT_UI_REF
UI_PATH=
UI_NAME=ui-ux-pro-max
FORCE=1

[ "$#" -eq 0 ] || die "This script is interactive and does not accept command-line arguments."

REPO_ROOT=$(abspath "$(expand_path "$REPO_ROOT")")
[ -d "$REPO_ROOT" ] || die "Repo root not found: $REPO_ROOT"

printf 'Checking ui-ux-pro-max cache...\n'
cache_root=$REPO_ROOT/skills
download_ui_cache "$cache_root" "$UI_REPO" "$UI_REF" "$UI_PATH" "$UI_NAME" 0

printf '\nInstallation setup\n'
printf 'Repo root: %s\n' "$REPO_ROOT"
AGENT=$(prompt_agent)
DEST=$(prompt_dest "$AGENT")
MODE=$(prompt_mode)

mkdir -p -- "$DEST"
DEST=$(abspath "$DEST")

printf '\nSummary\n'
printf 'Target agent: %s\n' "$AGENT"
printf 'Target skills dir: %s\n' "$DEST"
printf 'Install mode: %s\n' "$MODE"
printf 'ui-ux-pro-max cache: %s\n' "$cache_root/$UI_NAME"
printf 'Overwrite existing target entries: yes\n'
confirm_install

printf '\nInstalling skills...\n'
local_found=0
while IFS= read -r skill_dir; do
  [ -n "$skill_dir" ] || continue
  local_found=1
  install_skill "$skill_dir" "$DEST" "$(basename -- "$skill_dir")" "$MODE" "$FORCE"
done <<EOF
$(discover_local_skills "$REPO_ROOT")
EOF
[ "$local_found" = "1" ] || die "No local skills found under $REPO_ROOT"

install_skill "$cache_root/$UI_NAME" "$DEST" "$UI_NAME" "$MODE" "$FORCE"
