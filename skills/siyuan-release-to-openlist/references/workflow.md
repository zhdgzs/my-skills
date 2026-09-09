# 完整执行流程

本流程面向运行 OpenList 的 Linux 主机。它不依赖项目仓库，不执行 Git 操作，不创建 Release，也不构建或发布 Docker 镜像。

先确认当前 Shell。命令示例中的 `${NAME}` 是参数占位符，不要求使用特定 Shell；执行时优先传入已经核实的显式值，并使用独立命令调用，避免依赖 Bash、zsh 或 PowerShell 专有语法。

## 1. 明确输入

开始时确定以下值。括号内是默认值：

- `RELEASE_REPO`：GitHub Release 仓库（`openruan/siyuan`）
- `TAG`：目标稳定版标签，例如 `v3.8.3`
- `GH_ACCOUNT`：能读取 Release、查询 Actions 并删除 artifact 的账户（`openruan`）
- `CD_WORKFLOW`：生成 Release 的 workflow 名称或 ID（`CD For SiYuan`）
- `OPENLIST_CONTAINER`：OpenList 容器名（`openlist`）
- `OPENLIST_DATA_DIR`：宿主机 OpenList 数据目录（`/opt/1panel/apps/openlist/openlist/data`）
- `RELEASE_ROOT`：宿主机发布根目录（`${OPENLIST_DATA_DIR}/releases/siyuan`）
- `PUBLIC_URL`：OpenList 公网地址（`https://openlist.150524.xyz`）
- `MOUNT_PATH`：OpenList 中对应发布根目录的挂载路径（`/思源笔记`）
- `OLD_TAG`：用户明确要求替换的旧版本；未指定时不删除任何历史版本

标签必须严格匹配 `^v[0-9]+\.[0-9]+\.[0-9]+$`。用户说“最新版”时可以读取 Latest Release 确定标签；用户指定标签时不得静默改用 Latest。

## 2. 工具与 GitHub 授权

确认系统是 Linux，并检查 `gh`、`python3`、`docker`、`find`、`chmod`、`df` 和 `sha256sum`。OpenList 不使用 Docker 时可以省略 `docker`，但必须用等价只读检查证明进程、数据目录和公网服务对应同一实例。缺少工具时报告安装命令和影响，获得用户同意后再安装；不得自动全局安装软件。

执行 `gh auth status --hostname github.com`。若未登录，运行交互式 `gh auth login --hostname github.com --web`，让用户在浏览器或设备页面完成授权。私有仓库通常需要 `repo` 权限，删除 Actions artifact 还要求该账户对仓库具有相应写权限。只检查权限结果，不读取或显示 token。

在切换账户前，用 `gh api user --jq .login` 记录原活动账户。多账户环境使用 `gh auth switch --hostname github.com --user "${GH_ACCOUNT}"`，然后重新执行 `gh auth status --hostname github.com` 和 `gh repo view "${RELEASE_REPO}"`。操作结束后切回原账户并验证。

授权失败、仓库不可见或删除权限无法确认时停止。不要尝试从配置文件提取 token，也不要把 token 放入环境日志、参数文件或命令输出。

## 3. 验收 GitHub Release

使用 `gh release view "${TAG}" --repo "${RELEASE_REPO}" --json tagName,name,isDraft,isPrerelease,publishedAt,url,targetCommitish,assets`。同时读取 `repos/${RELEASE_REPO}/releases/latest`，确认目标是否为 Latest；目标不是 Latest 不一定失败，但必须如实报告。

要求 Release 非草稿、非预发布、标签与输入完全一致。将标签中的版本号记为 `VERSION=${TAG#v}`，预期集合固定为：

- `SHA256SUMS.txt`
- `siyuan-${VERSION}-linux.AppImage`
- `siyuan-${VERSION}-linux.deb`
- `siyuan-${VERSION}-linux.rpm`
- `siyuan-${VERSION}-linux.tar.gz`
- `siyuan-${VERSION}-mac-arm64.dmg`
- `siyuan-${VERSION}-mac.dmg`
- `siyuan-${VERSION}-win.exe`
- `siyuan-${VERSION}.apk`

要求集合完全相等、所有资产状态为 uploaded 且非空。计算 9 个资产大小总和 `ASSET_BYTES`。存在缺失、额外、空文件或上传未完成时停止。

## 4. 唯一定位生成 Release 的 CD run

在删除前先定位并记录候选 run，但此阶段不删除任何东西。

1. 读取标签引用 `repos/${RELEASE_REPO}/git/ref/tags/${TAG}`。如果对象类型是 `tag`，继续读取 `repos/${RELEASE_REPO}/git/tags/<sha>`，直到得到提交 SHA；不得仅使用 Release 的 `targetCommitish`，它可能只是 `master`。
2. 使用 `gh run list --repo "${RELEASE_REPO}" --workflow "${CD_WORKFLOW}"` 和 Actions API 查询候选 run。
3. 优先要求 workflow 名称匹配、结论为 `success`、`head_sha` 等于标签提交，并且运行时间覆盖 Release 资产创建时间。标签 push 通常以 `${TAG}` 为 `head_branch`；恢复构建可能是 `workflow_dispatch`，此时需要检查输入和日志。
4. 如果有多个成功候选或无法证明哪个 run 上传了当前 Release，停止并报告候选，不得按“最新一次”猜测。
5. 对唯一 run 调用 `repos/${RELEASE_REPO}/actions/runs/<run-id>/artifacts`，记录每个 artifact 的 ID、名称、大小、过期状态和总字节数。失败 run 的 artifact 不在删除范围内。

如果该 run 的 artifact 已经是零，记录为幂等状态；后续仍需完成 OpenList 验收，但不需要执行删除请求。

## 5. 验证本机确实运行目标 OpenList

检查 OpenList 容器或服务正在运行，公网地址可访问。Docker 部署至少执行：

- `docker ps` 确认 `${OPENLIST_CONTAINER}` 处于 running 状态
- `docker inspect "${OPENLIST_CONTAINER}" --format '{{json .Mounts}}'` 获取真实绑定挂载
- 确认 `${OPENLIST_DATA_DIR}` 被挂载到容器数据目录，并且 `${RELEASE_ROOT}` 位于该绑定挂载下
- 确认 `${OPENLIST_DATA_DIR}/data.db` 存在，且 `${RELEASE_ROOT}/.staging` 位于同一文件系统

只读查询 OpenList 数据库时只选择需要的字段。可读取 `x_storages` 的 `mount_path`、`driver`、`status`、`disabled`，以及 `x_meta` 是否存在密码；不要输出 `addition`、访问密码或其他凭据。挂载路径、宿主目录、容器目录和公网实例不能形成可证明的对应关系时停止。

## 6. 目标目录与磁盘计划

如果 `${RELEASE_ROOT}/${TAG}` 已存在，先运行验收脚本。文件集合与 SHA256 完全通过时视为幂等本地成功，跳过下载和移动；任何不一致都停止，不得覆盖已经公开的目录。

正常下载前要求可用空间大于 `ASSET_BYTES + 512 MiB`。优先保留旧版本直到新版本完整发布，以避免服务空窗。空间不足时：

1. 报告当前空间、所需空间和差额。
2. 计算删除用户指定 `${OLD_TAG}` 后是否足够；没有 `OLD_TAG` 时不得选择历史版本代删。
3. 只读检查可恢复缓存，例如 DNF/APT 缓存、日志或 Docker build cache，列出精确大小和影响。不得直接执行广泛的 Docker prune。
4. 在删除旧版本或清理缓存前取得独立明确确认。如果必须先删旧版本，明确说明从删除到新版本原子发布之间存在服务空窗。

确认格式：

```text
⚠️ 危险操作检测！
操作类型：[删除旧版本/清理缓存/删除 Actions artifact]
影响范围：[精确路径、run ID、artifact ID、数量和大小]
风险评估：[中断窗口、不可恢复内容和恢复来源]

请确认是否继续？[需要明确的“是”“确认”或“继续”]
```

旧版本删除前尽可能执行其 `SHA256SUMS.txt` 校验，并确认对应 GitHub Release 仍可作为恢复来源。删除必须限定到解析后的 `${RELEASE_ROOT}/${OLD_TAG}`，禁止使用未验证变量、通配符或宽泛递归目标。系统缓存只使用对应包管理器的标准清理命令，并单独复查空间。

## 7. 隐藏暂存、下载和本地校验

确认 `${RELEASE_ROOT}/.staging` 已存在且不对外列表。使用 `mktemp -d` 在其中创建本次唯一目录；记录其绝对路径，后续只允许清理这个目录。不要在公开版本目录中逐文件下载。

使用目标 GitHub 账户执行：

```text
gh release download "${TAG}" --repo "${RELEASE_REPO}" --dir "${STAGING_DIR}"
```

下载后要求暂存目录中只有 9 个预期普通文件：没有子目录、符号链接或其他文件，每个文件非空且大小与 Release 元数据一致。在暂存目录执行 `sha256sum --check "SHA256SUMS.txt"`，要求 8 个安装包全部为 `OK`。

校验失败时保留 Actions artifact。清理由本次创建的暂存目录时，不得跟随符号链接或递归处理意外子目录；遇到意外目录应停止并报告。不得删除其他 `.staging` 内容。

校验通过后将文件权限设为 `0644`，暂存目录权限设为 `0755`。再次确认 `${RELEASE_ROOT}/${TAG}` 不存在，再在同一文件系统中把 `${STAGING_DIR}` 原子移动为 `${RELEASE_ROOT}/${TAG}`。移动后复查权限、文件集合和剩余空间。

## 8. OpenList 公网验收

运行 Skill 自带脚本：

```text
python3 <skill-dir>/scripts/verify_openlist_release.py --release-root "${RELEASE_ROOT}" --tag "${TAG}" --public-url "${PUBLIC_URL}" --mount-path "${MOUNT_PATH}" --database "${OPENLIST_DATA_DIR}/data.db"
```

脚本会完成本地集合、普通文件、非空、SHA256、目录列表、版本列表、`SHA256SUMS.txt` Range `206` 和匿名 mkdir 业务码 `403` 验收。目录有访问密码时，脚本从 OpenList SQLite 数据库只读获取并仅在内存中使用；输出中不包含密码或签名下载 URL。

如果无法读取本机数据库，可将密码放入只属于当前进程的环境变量，并使用 `--password-env <变量名>`；不要把密码作为命令行参数。脚本报告匿名写入意外成功时，记录其输出的精确测试路径并停止，不得删除 artifact；清理意外创建内容属于新的写操作，需要确认。

## 9. 删除旧版本

磁盘允许保留旧版本时，应在新版本完成本地与公网验收后再删除 `${OLD_TAG}`。重新列出精确路径和大小并取得确认；如果步骤 6 已因空间不足提前确认并删除，则只记录结果，不重复操作。

删除后列出版本目录。默认不清理其他历史版本；用户未指定的版本只报告占用和可恢复来源。

## 10. 删除精确 run 的 Actions artifact

仅在步骤 8 全部通过后执行。再次查询唯一成功 run 的 artifact，防止使用过期列表。展示 run URL、artifact ID、名称、数量和总大小，并取得明确确认。

对重新查询得到的每个 artifact ID 调用：

```text
gh api --method DELETE "repos/${RELEASE_REPO}/actions/artifacts/<artifact-id>"
```

删除后反复读取 `repos/${RELEASE_REPO}/actions/runs/<run-id>/artifacts`，直到 `total_count` 为 `0` 且大小合计为 `0`，或 API 明确失败。不得删除 run 本身。随后再次读取 Release，确认仍为非草稿、非预发布，并保留完整 9 个资产。

## 11. 收尾与报告

确认本次暂存目录已消失、`.staging` 中没有本次残留，列出本地版本和磁盘余量。切回执行前记录的 GitHub 账户并验证；恢复失败时明确报告当前账户。

最终报告：目标版本、Release URL、CD run URL、下载与 SHA256、本地目录、公网列表、Range `206`、匿名写入 `403`、删除的旧版本、删除的 artifact 数量与大小、Release 资产保留状态、剩余磁盘空间和账户恢复状态。

任何关卡失败都只报告已完成的部分和下一步，不得把本地下载成功、Release 成功或 artifact 删除成功单独描述为完整流程成功。
