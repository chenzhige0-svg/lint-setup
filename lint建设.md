# lint 建设

一套可复制的 lint / format / 安全扫描方案，覆盖 **编辑器 → zsh → Git 钩子 → CI** 四层关卡。
本仓库同时提供配置文件、安装脚本、项目接入脚本和 CI 模板。

- 适用系统：Windows + WSL2（Ubuntu 24.04）为主，也说明纯 Windows / 纯 Linux 的差异
- 设计目标：规则只写一份、提交足够快、能自动修复就自动修复、编辑器与钩子使用同一套工具
- 所有工具都安装在用户目录，默认不需要 sudo

---

## 1. 总体架构

```text
编辑器（保存时）  →  zsh（手动/批量）  →  Git 钩子（commit/push）  →  CI（全量）
        ↘                  ↘                     ↘
         OpenCode formatter（写文件后） + AGENTS.md（Agent 主动跑 CLI）
```

四条原则：

1. **单一事实源**
   - Python：`pyproject.toml`（Ruff / Bandit / Pyright）
   - 前端：`.prettierrc`、`eslint.config.mjs`、`stylelint.config.mjs`
   - C/C++：`.clang-format`、`.clang-tidy`、`.clangd`
   - Shell：`.shellcheckrc`
   - 编辑器、zsh、pre-commit、OpenCode、CI 都读同一份配置。
2. **按速度分层**
   - commit：只跑改动文件 + 毫秒级检查
   - pre-push：类型检查、C/C++ 分析、Go/Rust 重型检查
   - CI：全量 + 密钥全历史扫描
3. **自动修复优先**
   - 能 `--fix` 的先修；格式化与 lint 分开跑，避免互相覆盖。
4. **版本一致**
   - 编辑器、钩子、OpenCode 调用同一个二进制，避免出现「终端过了、提交挂了」。

---

## 2. 配置清单

### 2.1 仓库文件

```text
lint-setup/
├── lint建设.md                 # 本文档
├── README.md
├── LICENSE
├── configs/                    # 复制到项目根目录的配置
│   ├── pyproject.toml          # Ruff + Bandit + Pyright
│   ├── .prettierrc.json
│   ├── .prettierignore
│   ├── eslint.config.mjs
│   ├── stylelint.config.mjs
│   ├── .markdownlint-cli2.yaml
│   ├── .yamllint.yaml
│   ├── .hadolint.yaml
│   ├── .shellcheckrc
│   ├── .clang-format
│   ├── .clang-tidy
│   ├── .clangd
│   ├── .editorconfig
│   ├── .gitattributes
│   ├── .gitleaks.toml
│   ├── .pre-commit-config.yaml
│   ├── rustfmt.toml
│   ├── clippy.toml
│   └── .golangci.yml
├── optional/                   # 不参与主链路的备选方案
│   ├── ruff.toml
│   ├── pyrightconfig.json
│   ├── mypy.ini
│   ├── .flake8
│   ├── uncrustify.cfg
│   └── lefthook.yml
├── zsh/
│   └── lint.zsh                # lint / format 函数库
├── editor/
│   ├── vscode-settings.json    # WSL 侧 VS Code 用户设置
│   └── extensions.txt          # 扩展清单
├── agent/
│   └── AGENTS.md.lint          # 项目 AGENTS.md 的 lint 协议片段
├── scripts/
│   ├── install-wsl.sh          # WSL 一键安装工具链
│   ├── windows-setup.ps1       # Windows 基础软件与 Git 配置
│   ├── install-vscode-extensions.sh
│   └── bootstrap-project.sh    # 往已有项目接入配置
└── ci/
    ├── lint.yml                # GitHub Actions
    └── install-lint-tools.sh
```

### 2.2 安装后的位置

| 内容                      | 位置                                                            |
| ------------------------- | --------------------------------------------------------------- |
| 工具链配置                | `~/.config/dev-toolbox/`                                        |
| zsh 函数库                | `~/.config/zsh/lint.zsh`                                        |
| VS Code（WSL Remote）设置 | `~/.vscode-server/data/Machine/settings.json`                   |
| 可执行文件                | `~/.local/bin`、`~/.cargo/bin`、`~/.local/go/bin`、nvm 全局目录 |
| pre-commit 缓存           | `~/.cache/pre-commit`                                           |

### 2.3 工具选型

| 场景                 | 主链路                                   | 说明                                        |
| -------------------- | ---------------------------------------- | ------------------------------------------- |
| Python lint / format | **Ruff**                                 | 替代 flake8 / isort / black                 |
| Python 类型          | **Pyright**                              | 与 mypy 二选一，主链路只留 Pyright          |
| Python 安全          | **bandit**                               | commit 阶段扫描 `src/app/scripts/tools`     |
| JS / TS              | **ESLint + Prettier**                    | 不使用 Biome，避免与 ESLint/Prettier 冲突   |
| CSS / SCSS           | **stylelint**                            | 有前端时启用                                |
| Markdown             | **markdownlint-cli2 + Prettier**         | 结构检查与格式化分离                        |
| Shell                | **ShellCheck + shfmt**                   | shfmt 统一 `-i 2 -ci -sr`                   |
| C / C++              | **clang-format + clang-tidy + cppcheck** | clang-tidy 在 pre-push 运行，需要编译数据库 |
| Go                   | **gofmt + golangci-lint**                | pre-push 运行                               |
| Rust                 | **rustfmt + clippy**                     | pre-push 运行                               |
| Dockerfile / YAML    | **hadolint / yamllint**                  | commit 阶段                                 |
| 密钥扫描             | **gitleaks**                             | commit 扫工作区，CI 扫全历史                |
| 钩子编排             | **pre-commit**                           | 不使用 lefthook                             |

不启用的工具（配置保留在 `optional/`）：

- `mypy`、`flake8`、`pylint`：被 Ruff / Pyright 覆盖，遗留项目再单独开
- `Biome`：与 ESLint / Prettier 功能重叠
- `lefthook`：与 pre-commit 只选一个
- `cpplint`、`uncrustify`：仅 ROS / Google 风格项目使用

---

## 3. 新电脑配置总览

推荐方式：**Windows 上只装 VS Code + Git + WSL，所有 lint 工具装在 WSL Ubuntu 里，通过 Remote-WSL 使用。**

原因：

- 工具链只维护一份（Linux 二进制）
- 仓库放在 WSL 的 ext4 上，pre-commit / ESLint / clangd 不会因为 `/mnt/c` 的 9p 文件系统变慢
- 编辑器、终端、Agent 看到的路径和环境一致

流程：

1. Windows：安装 WSL2 + Ubuntu 24.04、Git、VS Code、Windows Terminal
2. WSL：克隆本仓库，运行 `scripts/install-wsl.sh`
3. WSL：运行 VS Code 扩展安装脚本（首次 Remote-WSL 连接后）
4. 项目：运行 `scripts/bootstrap-project.sh` 接入配置
5. CI：复制 `.github/workflows/lint.yml` 和安装脚本

---

## 4. Windows 配置

### 4.1 安装 WSL2 与 Ubuntu

在 **管理员 PowerShell** 中执行：

```powershell
wsl --install -d Ubuntu-24.04
wsl --set-default-version 2
wsl --update
```

完成后重启，首次进入 Ubuntu 时创建 Linux 用户名和密码。

### 4.2 安装基础软件

可以用 winget 手动安装：

```powershell
winget install --id Git.Git -e
winget install --id Microsoft.VisualStudioCode -e
winget install --id Microsoft.WindowsTerminal -e
```

或者运行仓库里的脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows-setup.ps1
```

### 4.3 Git 行尾配置

Windows 与 WSL 共用仓库时，建议关闭自动换行转换：

```powershell
git config --global core.autocrlf false
git config --global core.eol lf
git config --global init.defaultBranch main
```

WSL 内同样检查：

```bash
git config --global core.autocrlf false
git config --global core.eol lf
```

仓库里的 `.gitattributes` 会强制文本文件使用 LF，`.pre-commit-config.yaml` 里的
`mixed-line-ending --fix=lf` 会兜底修复。

### 4.4 VS Code

1. 在 Windows 版 VS Code 中安装 **WSL** 扩展（`ms-vscode-remote.remote-wsl`）。
2. 用 `Ctrl+Shift+P` → `WSL: Connect to WSL` 连接 Ubuntu。
3. 首次连接会在 WSL 内生成 `~/.vscode-server`。
4. 在 WSL 终端执行：

```bash
bash scripts/install-vscode-extensions.sh
```

扩展清单见 `editor/extensions.txt`。要点：

- 不要同时启用 Pylance 和 Pyright：本方案 Python 使用 Ruff 格式化 + Pyright 类型检查
- 不要在同一个项目里同时启用 Prettier 和 Biome
- 扩展安装在 **WSL Remote 侧**，不是 Windows 本地侧

WSL 侧的设置文件：

```text
~/.vscode-server/data/Machine/settings.json
```

`scripts/install-wsl.sh` 会在该位置生成一份设置（已存在则不覆盖）。

### 4.5 目录放在哪里

推荐：

```text
Windows:  \\wsl$\Ubuntu-24.04\home\<user>\workspace
WSL:      ~/workspace
```

不要把频繁跑 lint 的仓库放在 `/mnt/c/...`，pre-commit 和 node_modules 会明显变慢。

---

## 5. WSL Ubuntu 配置

### 5.1 克隆仓库

```bash
mkdir -p ~/workspace
cd ~/workspace
git clone https://github.com/chenzhige0-svg/lint-setup.git
cd lint-setup
```

### 5.2 一键安装

```bash
bash scripts/install-wsl.sh
```

默认安装：

- Python：Ruff、bandit、yamllint、pre-commit、clang-format、clang-tidy、shellcheck、shfmt
- Node：ESLint、Prettier、TypeScript、typescript-eslint、stylelint、markdownlint-cli2、pyright
- 二进制：hadolint、gitleaks、golangci-lint
- 配置：复制到 `~/.config/dev-toolbox/`
- zsh：复制 `lint.zsh` 并把加载语句写入 `~/.zshrc`
- VS Code：生成 WSL 侧 `settings.json`（不覆盖已有文件）

可选参数：

```bash
bash scripts/install-wsl.sh --with-go      # 安装 Go
bash scripts/install-wsl.sh --with-rust    # 安装 Rust + clippy + rustfmt
bash scripts/install-wsl.sh --force        # 覆盖已存在的工具配置
```

### 5.3 手动安装（有 sudo 时）

```bash
sudo apt update
sudo apt install -y shellcheck shfmt clang-format clang-tidy cppcheck clangd

python3 -m pip install --user \
  ruff bandit yamllint pre-commit \
  clang-format clang-tidy shellcheck-py shfmt-py

npm install -g \
  eslint @eslint/js typescript-eslint globals prettier typescript \
  stylelint stylelint-config-standard markdownlint-cli2 pyright

# hadolint / gitleaks / golangci-lint 从 GitHub Releases 下载到 ~/.local/bin
```

Ubuntu 24.04 的系统 Python 受 PEP 668 保护。如果 `pip install --user` 被拒绝：

- 推荐先安装 Miniconda，在 base 环境里执行；或
- 使用 `pipx install <工具>`；或
- 使用仓库脚本的自动回退逻辑（uv / pipx）

### 5.4 验证

```bash
exec zsh

ruff --version
pyright --version
eslint --version
prettier --version
shellcheck --version
clang-format --version
pre-commit --version
gitleaks version
```

再验证钩子配置：

```bash
pre-commit validate-config ~/.config/dev-toolbox/.pre-commit-config.yaml
```

### 5.5 zsh 函数库

`~/.zshrc` 会加载 `~/.config/zsh/lint.zsh`，提供：

```bash
lint py          # ruff check .
fix-py           # ruff check --fix + ruff format
type-py          # pyright
lint sh          # 所有 git 跟踪的 .sh/.bash
fmt-sh           # shfmt -w -i 2 -ci -sr
lint js / fmt-js / type-js
lint css / lint md / lint yaml / lint docker
lint cpp / fmt-cpp / lint-tidy
lint go / fmt-go / lint rs / fmt-rs
lint stage       # pre-commit run（暂存区）
lint all         # pre-commit run --all-files
lint push        # pre-commit run --all-files --hook-stage pre-push
```

---

## 6. 项目接入

### 6.1 自动接入

```bash
bash scripts/bootstrap-project.sh ~/workspace/my-project
```

脚本会：

- 复制缺失的配置到项目根目录（已存在的不覆盖）
- 如果项目已有 `pyproject.toml`，把 lint 配置写成 `pyproject.lint-snippet.toml` 供手动合并
- 可选复制 CI 模板（`--with-ci`）
- 在 Git 仓库里执行 `pre-commit install --install-hooks`

### 6.2 手动接入

```bash
cd ~/workspace/my-project

cp ~/.config/dev-toolbox/{pyproject.toml,.prettierrc.json,.prettierignore} .
cp ~/.config/dev-toolbox/{eslint.config.mjs,stylelint.config.mjs} .
cp ~/.config/dev-toolbox/{.markdownlint-cli2.yaml,.yamllint.yaml,.hadolint.yaml,.shellcheckrc} .
cp ~/.config/dev-toolbox/{.clang-format,.clang-tidy,.clangd,.editorconfig,.gitattributes} .
cp ~/.config/dev-toolbox/{.gitleaks.toml,.pre-commit-config.yaml} .
cp ~/.config/dev-toolbox/{rustfmt.toml,clippy.toml,.golangci.yml} .   # 按需

pre-commit install --install-hooks
pre-commit run --all-files
```

已有 `pyproject.toml` 时只合并这些段落，不要覆盖项目元数据：

```toml
[tool.ruff]
[tool.ruff.lint]
[tool.ruff.format]
[tool.bandit]
[tool.pyright]
```

### 6.3 前端项目依赖

项目内安装依赖，版本跟随项目：

```bash
npm i -D eslint @eslint/js typescript-eslint globals \
         prettier typescript stylelint stylelint-config-standard markdownlint-cli2
```

---

## 7. 钩子矩阵

| 阶段             | 执行内容                                                                                                                                         | 目标耗时 |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | -------- |
| commit           | 通用卫生、gitleaks、Ruff、bandit、ShellCheck、shfmt、Prettier、ESLint、stylelint、markdownlint、yamllint、hadolint、clang-format、gofmt、rustfmt | < 3 s    |
| pre-push         | Pyright、tsc、cppcheck、clang-tidy、golangci-lint、clippy                                                                                        | < 60 s   |
| 手动 commit 全量 | `pre-commit run --all-files`                                                                                                                     | 秒级     |
| 手动重型         | `pre-commit run --all-files --hook-stage pre-push`                                                                                               | 分钟级   |
| CI               | 两个阶段 + gitleaks 全历史                                                                                                                       | 2–5 min  |

要点：

- 没有匹配文件的 hook 不会执行。纯 Python 项目不会运行 C++/Go/Rust 检查。
- 首次运行带自动修复的 hook 会修改文件并返回失败，重新 `git add` 后再跑一次即可。
- 不要用 `git commit --no-verify` 绕过；CI 是最后一道门禁。

---

## 8. 编辑器配置

- 全局关闭 `editor.formatOnSave`
- 按语言显式打开：
  - Python：Ruff 格式化，保存时 `source.fixAll.ruff` / `source.organizeImports.ruff`
  - JS/TS/CSS/Markdown/YAML/JSON：Prettier
  - Shell：shell-format（`-i 2 -ci -sr`），ShellCheck 保存时运行
  - C/C++：clang-format；clangd 负责补全和 clang-tidy 诊断
- `prettier.requireConfig: true`：没有 `.prettierrc` 的项目不会被乱格式化
- Markdown 的格式化交给 Prettier，结构检查交给 markdownlint；MD013 放宽到 120

完整设置见 `editor/vscode-settings.json`。

---

## 9. OpenCode / Agent

全局配置示例（`~/.config/opencode/opencode.jsonc`）：

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "formatter": {
    "ruff": {
      "command": ["ruff", "format", "$FILE"],
      "extensions": [".py", ".pyi"],
    },
    "shfmt": {
      "command": ["shfmt", "-w", "$FILE"],
      "extensions": [".sh", ".bash"],
    },
    "clang-format": {
      "command": ["clang-format", "-i", "$FILE"],
      "extensions": [".c", ".h", ".cc", ".cpp", ".cxx", ".hpp", ".hxx"],
    },
    "prettier": {
      "command": ["prettier", "--write", "$FILE"],
    },
  },
  "lsp": false,
}
```

说明：

- `formatter` 只格式化 Agent 自己改过的文件
- `lsp: false` 是有意为之：让 Agent 直接跑 lint / typecheck CLI，拿到真实退出码
- API key 不要写进配置文件，使用 `{env:...}` 或 `{file:...}` 引用
- 项目里的 `AGENTS.md` 加上 `agent/AGENTS.md.lint` 的协议，禁止 `--no-verify`

---

## 10. CI

复制模板：

```bash
mkdir -p .github/workflows .github/scripts
cp ci/lint.yml .github/workflows/lint.yml
cp ci/install-lint-tools.sh .github/scripts/
chmod +x .github/scripts/install-lint-tools.sh
```

Workflow 会执行：

1. 安装 system hook 需要的工具
2. `pre-commit run --all-files`
3. `pre-commit run --all-files --hook-stage pre-push`
4. `gitleaks git --log-opts="--all"` 扫全历史

有 Go / Rust 项目时取消 workflow 里的 `setup-go` / `rust-toolchain` 注释。
ROS 2 项目可以在 CI 额外跑 `ament_flake8` / `ament_cpplint` / `ament_uncrustify`，
本地不要同时维护两套风格门禁。

---

## 11. 辅助脚本

| 脚本                                   | 用途                                                 |
| -------------------------------------- | ---------------------------------------------------- |
| `scripts/install-wsl.sh`               | 在 WSL 用户目录安装全部工具、复制配置、接入 zsh      |
| `scripts/windows-setup.ps1`            | 安装 Git / VS Code / Windows Terminal，设置 Git 行尾 |
| `scripts/install-vscode-extensions.sh` | 在 WSL Remote 侧安装扩展                             |
| `scripts/bootstrap-project.sh`         | 把配置复制到已有项目并安装 pre-commit                |
| `ci/install-lint-tools.sh`             | GitHub Actions 里安装 system hook 工具               |

---

## 12. 常见问题

1. **pre-commit 第一次失败**
   自动修复 hook 修改了文件，重新 `git add` 后重跑即可。

2. **GUI / IDE 提交时找不到 ruff / node**
   GUI 不会加载 `.zshrc`。WSL 里工具已软链到 `~/.local/bin`；必要时从终端提交，
   或重启 VS Code Server 让 PATH 生效。

3. **ESLint 插件找不到**
   优先在项目里 `npm i -D`；本仓库的 `eslint.config.mjs` 在找不到本地依赖时会回退到
   `~/.config/dev-toolbox/node_modules`（安装脚本会创建软链）。

4. **clang-tidy 报找不到编译数据库**
   CMake：`-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`
   ROS：`colcon build --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`
   本方案默认读取 `build/`。

5. **CRLF / 文件模式抖动**
   同时使用 `.gitattributes`、`mixed-line-ending --fix=lf`、Git 的 `core.autocrlf false`。

6. **`/mnt/c` 上 pre-commit 很慢**
   仓库放到 WSL ext4，例如 `~/workspace`。

7. **Ruff 与 ament_flake8 行宽不一致**
   本方案 Ruff 行宽设为 99，对齐 ament；ROS 的 ament 检查仍只在 CI 跑。

8. **Prettier 与 markdownlint 的 MD013 冲突**
   MD013 放宽到 120，并关闭表格/代码块检查；折行交给 Prettier。

9. **密钥扫描**
   gitleaks 只能防新增泄漏。密钥一旦提交过，应立即轮换，不能只靠删除文件。

---

## 13. 验收清单

新电脑配置完成后，逐项确认：

- [ ] `wsl --status` 显示 WSL2，Ubuntu 24.04 可进入
- [ ] `git config --global core.autocrlf` 为 `false`
- [ ] `ruff --version`、`pyright --version`、`eslint --version` 正常
- [ ] `pre-commit validate-config ~/.config/dev-toolbox/.pre-commit-config.yaml` 通过
- [ ] `exec zsh` 后 `lint py` 可用
- [ ] VS Code 通过 Remote-WSL 连接，扩展安装成功
- [ ] 项目里 `pre-commit run --all-files` 通过
- [ ] `git commit` 能在 3 秒内完成
- [ ] CI 的 commit / pre-push 两阶段都能跑通
- [ ] 伪造一个密钥能被 gitleaks 拦截
