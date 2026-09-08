---
name: release-to-openlist
description: 将已发布的 SiYuan GitHub Release 安全同步到本机 OpenList，按需替换旧版本，并在完整验收后删除对应成功 GitHub Actions run 的制品。适用于 Release 已存在、需要在独立 Linux/OpenList 主机完成接收与清理的场景；不用于同步源码、构建安装包、发布 Docker 镜像或创建 Release。
---

# Release To OpenList

将一个已经发布的稳定版 SiYuan Release 接收到本机 OpenList。这个 Skill 独立于任何项目仓库运行，不要求当前目录是 Git 仓库。

## 默认值

- GitHub Release 仓库：`openruan/siyuan`
- GitHub 账户：`openruan`
- CD workflow：`CD For SiYuan`
- OpenList 容器：`openlist`
- OpenList 数据目录：`/opt/1panel/apps/openlist/openlist/data`
- 本地发布根目录：`/opt/1panel/apps/openlist/openlist/data/releases/siyuan`
- OpenList 公网地址：`https://openlist.150524.xyz`
- OpenList 挂载路径：`/思源笔记`

用户提供不同值时使用用户值。不能从当前机器可靠发现的值必须询问，不得猜测生产路径、仓库或账户。

## 入口规则

1. 在采取任何写操作前完整阅读 [references/workflow.md](references/workflow.md)。
2. 先收集版本、仓库、GitHub 账户、OpenList 部署和待替换版本；只询问无法安全推断的必要信息。
3. GitHub CLI 未登录时，引导用户完成 `gh auth login`；多账户环境切换到目标账户，结束时恢复原账户。不得读取、输出或持久化令牌。
4. Release 必须是非草稿、非预发布的 `vX.Y.Z` 稳定版，且包含 SiYuan 约定的 8 个安装包和 `SHA256SUMS.txt`。
5. 下载必须进入发布根目录同一文件系统中的唯一 `.staging` 目录。文件集合、类型、大小和 SHA256 全部通过后，才可原子移动为公开版本目录。
6. 旧版本应在本地与公网验收通过后删除；仅当磁盘不足、用户明确批准服务空窗且删除后空间满足门槛时，才可提前删除指定旧版本。Actions artifact 始终只能在完整验收后删除。目标目录损坏、run 归属不唯一或公网验收失败时停止，并保留诊断制品。
7. 删除旧版本、清理系统缓存和删除 Actions artifact 前必须列出精确对象、影响与恢复方式，并取得明确确认。用户对其中一个动作的批准不自动授权其他动作。
8. 只删除生成本次 Release 的唯一成功 CD run 的 artifact。不得删除 workflow run、Release、Release 资产、其他 run 的 artifact 或失败 run 的诊断制品。
9. 使用 [scripts/verify_openlist_release.py](scripts/verify_openlist_release.py) 完成确定性的本地文件、SHA256、OpenList 列表、Range 和匿名写入拒绝验收。脚本失败时不得继续删除 artifact。

## 完成条件

只有以下条件同时满足才能报告完整成功：

- 新版本目录由原子移动发布，文件权限正确，暂存目录无本次残留
- 8 个安装包全部通过 `SHA256SUMS.txt`
- 不登录访客能在 OpenList 中看到版本和 9 个资产；受密码保护时允许使用目录访问密码，但不得使用管理员登录
- `SHA256SUMS.txt` 的 Range 请求返回 HTTP `206`
- 匿名创建目录请求的 HTTP 外层状态为 `200`，OpenList 业务码为 `403`
- 精确 CD run 的 artifact 数量和总字节数均为 `0`
- GitHub Release 仍是正式版并保留完整 9 个资产
- GitHub CLI 已恢复执行前账户，或明确报告无法恢复

报告 Release URL、run URL、本地目录、公网验收、删除对象、剩余磁盘空间和任何未完成项。不得把部分成功描述为完整完成。
