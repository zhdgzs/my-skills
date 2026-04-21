# my-skills

这是一个面向网站交付流程的可移植 skills 仓库。

当前仓库包含：

- `site-deployer`：总入口 skill，用于端到端网站交付
- `site-generator`：静态网站生成
- `nginx-site-manager`：Nginx 站点配置管理
- `feishu-form-bridge`：表单后端，将提交数据写入飞书

仓库内还提供了一个 bootstrap 脚本，用于：

- 将本仓库的 skills 安装到目标 agent 的 skills 目录
- 缺少 `ui-ux-pro-max` 时自动下载并安装

## 目录结构

```text
my-skills/
├── scripts/
│   └── bootstrap_skills.sh
├── skills/
│   ├── feishu-form-bridge/
│   ├── nginx-site-manager/
│   ├── site-deployer/
│   ├── site-generator/
│   └── ui-ux-pro-max/
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

### 2. 运行安装脚本

```bash
sh scripts/bootstrap_skills.sh
```

脚本启动后会先检查仓库中的 `skills/ui-ux-pro-max/`：

- 如果已经存在，直接复用
- 如果不存在，自动从 GitHub 下载并缓存

然后脚本会交互式询问：

- 目标 agent：`codex`、`claude`、`claude-code`、`custom`
- 目标 skills 目录
- 安装模式：`symlink` 或 `copy`
- `agent` 和安装模式都支持数字快捷输入

安装时会始终执行以下操作：

- 安装 `skills/` 目录下的全部 skills
- 如果目标位置已有同名目录，直接覆盖

## Bootstrap 脚本

脚本文件：

- [scripts/bootstrap_skills.sh](/root/my-skills/scripts/bootstrap_skills.sh)

这个脚本会：

- 启动时先检查 `skills/ui-ux-pro-max/`
- 本地没有缓存时自动下载 `ui-ux-pro-max`
- 自动发现 `skills/` 目录下的 skill 目录
- 安装到指定的 skills 目标目录
- 自动探测上游仓库里 `ui-ux-pro-max` 的实际 skill 路径
- 将下载结果缓存到 `skills/ui-ux-pro-max/`
- 交互式询问安装目标和安装模式
- 覆盖目标目录中已存在的同名 skill

说明：

- `symlink` 适合开发环境和基于 git 的持续更新
- `copy` 更适合不支持软链接的 agent 或环境
- 下载得到的 `skills/ui-ux-pro-max/` 已加入 Git 忽略，不需要提交

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
sh scripts/bootstrap_skills.sh
```

如果你在交互中选择的是 `symlink`，那么仓库内容更新后通常会立即生效，不需要重新复制。

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

本仓库不会直接 vendor 该 skill，而是通过 bootstrap 脚本本地下载、缓存并安装：

- <https://github.com/nextlevelbuilder/ui-ux-pro-max-skill>

## 兼容性说明

这个仓库在内容层面是 agent-agnostic 的：

- 每个 skill 都是标准目录，包含 `SKILL.md`
- 不同 agent 的差异主要体现在安装目录和外部 skill 路径

因此推荐的做法是：

- skill 内容仓库始终保持一份
- 不为不同 agent 复制多套 skill
- 差异通过安装脚本里的交互选择处理
