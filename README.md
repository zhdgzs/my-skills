# my-skills

这是一个面向网站交付流程的可移植 skills 仓库。

当前仓库包含：

- `site-deployer`：总入口 skill，用于端到端网站交付
- `site-generator`：静态网站生成
- `nginx-site-manager`：Nginx 站点配置管理
- `feishu-form-bridge`：表单后端，将提交数据写入飞书

仓库内还提供了一个 bootstrap 脚本，用于：

- 将本仓库的 skills 安装到目标 agent 的 skills 目录
- 从 GitHub 安装 `ui-ux-pro-max`

## 目录结构

```text
my-skills/
├── feishu-form-bridge/
├── nginx-site-manager/
├── scripts/
│   └── bootstrap_skills.py
├── site-deployer/
├── site-generator/
└── README.md
```

## 设计思路

本仓库采用“扁平 skill + 总入口编排”的方式，而不是把所有能力塞进一个大 skill：

- `site-deployer` 负责根据用户意图做流程路由
- 其他 skill 保持小而清晰，便于复用
- 每个 skill 既可以被总入口调用，也可以单独安装、单独触发

这样做的好处是：

- 编排逻辑和实现细节分离
- 更容易维护和扩展
- 更适合在不同 agent 之间复用

## 安装方式

### 1. 克隆仓库

```bash
git clone <your-repo-url> /opt/my-skills
cd /opt/my-skills
```

### 2. 安装到 Codex

```bash
python3 scripts/bootstrap_skills.py --agent codex
```

默认安装目录：

```text
~/.codex/skills
```

### 3. 安装到 Claude Code

```bash
python3 scripts/bootstrap_skills.py --agent claude
```

默认安装目录：

```text
~/.claude/skills
```

### 4. 安装到其他 agent

如果目标 agent 支持 skills 目录，但路径不是默认值，可以显式指定：

```bash
python3 scripts/bootstrap_skills.py --agent custom --dest /path/to/agent/skills
```

## Bootstrap 脚本

脚本文件：

- [scripts/bootstrap_skills.py](/root/my-skills/scripts/bootstrap_skills.py)

这个脚本会：

- 自动发现本仓库下的本地 skill 目录
- 安装到指定的 skills 目标目录
- 从 `nextlevelbuilder/ui-ux-pro-max-skill` 安装 `ui-ux-pro-max`

常用参数示例：

```bash
python3 scripts/bootstrap_skills.py --agent codex --mode symlink
python3 scripts/bootstrap_skills.py --agent codex --mode copy
python3 scripts/bootstrap_skills.py --agent codex --skip-ui
python3 scripts/bootstrap_skills.py --agent custom --dest /path/to/skills --ui-path <repo-path>
python3 scripts/bootstrap_skills.py --agent codex --force
```

说明：

- `symlink` 适合开发环境和基于 git 的持续更新
- `copy` 更适合不支持软链接的 agent 或环境
- `--force` 会覆盖已存在的安装目录

## Git 分发方式

推荐把这个仓库作为唯一事实来源：

1. 在一处维护 skills 内容
2. 在每台服务器上克隆该仓库
3. 运行 bootstrap 脚本，将 skills 安装到目标 agent
4. 后续通过 `git pull` 同步更新

示例：

```bash
cd /opt/my-skills
git pull
python3 scripts/bootstrap_skills.py --agent codex --force
```

如果你使用的是 `--mode symlink`，那么仓库内容更新后通常会立即生效，不需要重新复制。

## 推荐的远端初始化流程

本地已经初始化 git 之后，可以执行：

```bash
git remote add origin <your-repo-url>
git add .
git commit -m "Initial skills repository"
git push -u origin main
```

## 当前外部依赖

`site-generator` 依赖外部 skill：

- `ui-ux-pro-max`

本仓库不会直接 vendor 该 skill，而是通过 bootstrap 脚本从以下仓库单独安装：

- <https://github.com/nextlevelbuilder/ui-ux-pro-max-skill>

## 兼容性说明

这个仓库在内容层面是 agent-agnostic 的：

- 每个 skill 都是标准目录，包含 `SKILL.md`
- 不同 agent 的差异主要体现在安装目录和外部 skill 路径

因此推荐的做法是：

- skill 内容仓库始终保持一份
- 不为不同 agent 复制多套 skill
- 差异仅通过安装脚本参数处理
