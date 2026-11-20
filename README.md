# lint-setup

可复制的 lint / format / 安全扫描配置：编辑器 → zsh → Git 钩子 → CI 四层关卡。

完整文档：[`lint建设.md`](lint建设.md)

## 快速开始

### WSL Ubuntu

```bash
git clone https://github.com/chenzhige0-svg/lint-setup.git
cd lint-setup
bash scripts/install-wsl.sh
exec zsh
```

### 接入已有项目

```bash
bash scripts/bootstrap-project.sh ~/workspace/my-project --with-ci
cd ~/workspace/my-project
pre-commit run --all-files
```

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows-setup.ps1
```

然后在 WSL 中完成工具链安装，并用 VS Code 的 Remote-WSL 连接。

## 包含内容

- `configs/`：可直接复制到项目的 Ruff / Pyright / ESLint / Prettier / clang-format / pre-commit 等配置
- `zsh/lint.zsh`：`lint py`、`fix-py`、`lint sh`、`lint push` 等函数
- `scripts/`：WSL 安装、Windows 基础环境、VS Code 扩展、项目接入
- `editor/`：VS Code 设置与扩展清单
- `ci/`：GitHub Actions 两阶段门禁
- `optional/`：mypy / flake8 / lefthook / uncrustify 等备选方案

## 设计原则

1. 规则只写一份：Ruff 读 `pyproject.toml`，Prettier 读 `.prettierrc`，clang-format 读 `.clang-format`
2. 按速度分层：commit 只跑改动文件，类型检查和重型分析放 pre-push
3. 自动修复优先：能 `--fix` 的先修，格式化与 lint 分开
4. 编辑器、钩子、Agent 使用同一套工具版本

## 已验证环境

- Ubuntu 24.04 (WSL2)
- Node.js 22 / Python 3.13 / Go 1.27 / Rust 1.100
- Ruff 0.17、ESLint 10、Prettier 3.10、clang-format 18、pre-commit 4.7

## License

MIT
