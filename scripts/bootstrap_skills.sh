#!/bin/sh
set -eu

DEFAULT_UI_REPO="nextlevelbuilder/ui-ux-pro-max-skill"
DEFAULT_UI_REF="main"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEFAULT_REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "未找到必需命令：$1"
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

    IFS= read -r reply || die "输入已中断。"

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
    value=$(prompt_value "目标智能体 [1 codex, 2 claude, 3 claude-code, 4 自定义]" "1")
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
      自定义)
        printf 'custom\n'
        return 0
        ;;
      codex|claude|claude-code|custom)
        printf '%s\n' "$value"
        return 0
        ;;
      *)
        printf '请输入 1-4，或输入 codex、claude、claude-code、custom。\n' >&2
        ;;
    esac
  done
}

prompt_mode() {
  while :; do
    value=$(prompt_value "安装模式 [1 符号链接, 2 复制]" "1")
    case "$value" in
      1)
        printf 'symlink\n'
        return 0
        ;;
      2)
        printf 'copy\n'
        return 0
        ;;
      符号链接)
        printf 'symlink\n'
        return 0
        ;;
      复制)
        printf 'copy\n'
        return 0
        ;;
      symlink|copy)
        printf '%s\n' "$value"
        return 0
        ;;
      *)
        printf '请输入 1-2，或输入 symlink、copy。\n' >&2
        ;;
    esac
  done
}

prompt_overwrite() {
  while :; do
    value=$(prompt_value "已有目标条目 [1 覆盖, 2 跳过]" "1")
    case "$value" in
      1|覆盖|overwrite)
        printf '1\n'
        return 0
        ;;
      2|跳过|skip)
        printf '0\n'
        return 0
        ;;
      *)
        printf '请输入 1-2，或输入 覆盖、跳过、overwrite、skip。\n' >&2
        ;;
    esac
  done
}

display_agent() {
  case "$1" in
    custom)
      printf '自定义\n'
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

display_mode() {
  case "$1" in
    symlink)
      printf '符号链接\n'
      ;;
    copy)
      printf '复制\n'
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

display_overwrite() {
  case "$1" in
    1)
      printf '覆盖\n'
      ;;
    0)
      printf '跳过\n'
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

prompt_dest() {
  agent=$1
  default_value=
  if dest_guess=$(default_dest "$agent"); then
    default_value=$dest_guess
  fi

  while :; do
    value=$(prompt_value "目标技能目录" "$default_value")
    [ -n "$value" ] || continue
    printf '%s\n' "$(expand_path "$value")"
    return 0
  done
}

confirm_install() {
  while :; do
    value=$(prompt_value "继续安装？(y/n)" "y")
    case "$value" in
      y|Y|yes|YES|Yes|是|确认|继续)
        return 0
        ;;
      n|N|no|NO|No|否|取消)
        printf '已取消安装。\n'
        exit 0
        ;;
      *)
        printf '请输入 y 或 n。\n' >&2
        ;;
    esac
  done
}

discover_local_skills() {
  repo_root=$1
  skills_root=$repo_root/skills
  [ -d "$skills_root" ] || return 0
  for entry in "$skills_root"/*; do
    [ -d "$entry" ] || continue
    name=$(basename -- "$entry")
    case "$name" in
      .*)
        continue
        ;;
    esac
    [ -f "$entry/SKILL.md" ] || continue
    printf '%s\n' "$entry"
  done
}

target_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

ensure_empty_target() {
  target=$1
  force=$2
  if ! target_exists "$target"; then
    return 0
  fi
  [ "$force" = "1" ] || die "目标已存在：$target"
  rm -rf -- "$target"
}

ensure_safe_target() {
  src_abs=$1
  target=$2
  target_abs=$(abspath "$target")

  case "$target_abs" in
    "$src_abs"|"$src_abs"/*)
      die "安装目标不能是源技能目录本身或其子目录：$target_abs"
      ;;
  esac
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
      printf '本地  %-22s 已链接\n' "$skill_name"
      return 0
    fi
    if [ "$force" != "1" ] && target_exists "$target"; then
      printf '本地  %-22s 已存在，已跳过\n' "$skill_name"
      return 0
    fi
    ensure_safe_target "$src_abs" "$target"
    ensure_empty_target "$target" "$force"
    ln -s -- "$src_abs" "$target"
    printf '本地  %-22s 已创建链接\n' "$skill_name"
    return 0
  fi

  if [ "$force" != "1" ] && target_exists "$target"; then
    printf '本地  %-22s 已存在，已跳过\n' "$skill_name"
    return 0
  fi

  ensure_safe_target "$src_abs" "$target"
  ensure_empty_target "$target" "$force"
  cp -a -- "$src" "$target"
  printf '本地  %-22s 已复制\n' "$skill_name"
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
    printf '缓存  %-22s 已存在\n' "$skill_name"
    return 0
  fi

  case "$repo" in
    */*)
      owner=${repo%%/*}
      name=${repo#*/}
      ;;
    *)
      die "--ui-repo 无效，期望格式为 owner/repo：$repo"
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

  curl -fsSL "$url" -o "$archive" || die "下载失败：$repo@$ref"
  unzip -q "$archive" -d "$tmpdir" || die "解压失败：$repo@$ref"

  extracted_root=
  extracted_count=0
  for entry in "$tmpdir"/*; do
    [ -d "$entry" ] || continue
    extracted_root=$entry
    extracted_count=$((extracted_count + 1))
  done
  [ "$extracted_count" -eq 1 ] || die "GitHub 归档结构不符合预期。"

  resolved_source_path=$source_path
  if [ -z "$resolved_source_path" ]; then
    resolved_source_path=$(discover_ui_source "$extracted_root" "$skill_name") \
      || die "下载的仓库中未找到 $skill_name，请显式传入 --ui-path。"
  fi

  src=$extracted_root/$resolved_source_path
  [ -d "$src" ] || die "未找到 ui-ux-pro-max 源目录：$resolved_source_path"
  [ -f "$src/SKILL.md" ] || die "ui-ux-pro-max 源目录缺少 SKILL.md：$resolved_source_path"

  rm -rf -- "$cache_dir"
  cp -RL -- "$src" "$cache_dir"
  printf '缓存  %-22s 已从 %s@%s 下载（%s）\n' "$skill_name" "$repo" "$ref" "$resolved_source_path"

  trap - EXIT HUP INT TERM
  cleanup_download
}

REPO_ROOT=$DEFAULT_REPO_ROOT
UI_REPO=$DEFAULT_UI_REPO
UI_REF=$DEFAULT_UI_REF
UI_PATH=
UI_NAME=ui-ux-pro-max
FORCE=1

[ "$#" -eq 0 ] || die "此脚本为交互式脚本，不接受命令行参数。"

REPO_ROOT=$(abspath "$(expand_path "$REPO_ROOT")")
[ -d "$REPO_ROOT" ] || die "未找到仓库根目录：$REPO_ROOT"

printf '\n安装设置\n'
printf '仓库根目录：%s\n' "$REPO_ROOT"
printf '技能源目录：%s\n' "$REPO_ROOT/skills"
AGENT=$(prompt_agent)
DEST=$(prompt_dest "$AGENT")
MODE=$(prompt_mode)
FORCE=$(prompt_overwrite)

mkdir -p -- "$DEST"
DEST=$(abspath "$DEST")

printf '\n安装摘要\n'
printf '目标智能体：%s\n' "$(display_agent "$AGENT")"
printf '目标技能目录：%s\n' "$DEST"
printf '安装模式：%s\n' "$(display_mode "$MODE")"
printf '仓库技能来源：%s\n' "$REPO_ROOT/skills"
printf '已有目标条目处理：%s\n' "$(display_overwrite "$FORCE")"
confirm_install

printf '\n正在准备 ui-ux-pro-max 缓存...\n'
cache_root=$REPO_ROOT/skills
download_ui_cache "$cache_root" "$UI_REPO" "$UI_REF" "$UI_PATH" "$UI_NAME" 0

printf '\n正在安装技能...\n'
local_found=0
while IFS= read -r skill_dir; do
  [ -n "$skill_dir" ] || continue
  local_found=1
  install_skill "$skill_dir" "$DEST" "$(basename -- "$skill_dir")" "$MODE" "$FORCE"
done <<EOF
$(discover_local_skills "$REPO_ROOT")
EOF
[ "$local_found" = "1" ] || die "在 $REPO_ROOT/skills 下未找到技能"
